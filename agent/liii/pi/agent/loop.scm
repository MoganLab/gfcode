;;
;; Ported from @earendil-works/pi-coding-agent (https://github.com/earendil-works/pi)
;; Original work Copyright (c) 2025 Mario Ortiz Manero / Earendil Works
;; Goldfish Scheme port Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi agent loop)
  (import (scheme base)
    (liii string)
    (liii list)
    (liii pi ai abort)
    (liii pi ai config runtime)
    (liii pi ai message)
    (liii pi ai time)
    (liii pi ai dispatch)
    (liii pi agent tools)
    (liii pi agent cost)
    (liii pi agent budget)
    (liii pi agent loop-queue)
  ) ;import
  (export pi-step-agent-turn pi-notify-turn-end pi-emit-agent-end
    pi-finish-agent-turn pi-emit-agent-error pi-maybe-compact pi-handle-tool-use
    run-agent-loop pi-resolve-turn-system-prompt
  ) ;export
  (begin

    (define (%ext-emit config)
      (let ((val (pi-cfg-ref config 'emit-extension-event)))
        (and (procedure? val) val)
      ) ;let
    ) ;define

    (define (%resolve-effective-cfg config)
      (let ((prepare (pi-cfg-ref config 'prepare-request #f)))
        (if (procedure? prepare) (prepare config) config)
      ) ;let
    ) ;define

    ;; usage 是否携带有效 token 计数：错误占位消息（max-turns / 会话超时 / 请求异常）
    ;; usage 全零或仅含 cost 等非计数字段，不能用于上下文占比换算
    (define (%usage-has-tokens? usage)
      (and (pair? usage)
        (let loop
          ((rest usage))
          (and (pair? rest)
            (or (and (pair? (car rest))
                  (memq (caar rest) '(input output totalTokens total cacheRead
                                       cacheWrite))
                  (number? (cdar rest))
                  (> (cdar rest) 0)
                ) ;and
              (loop (cdr rest))
            ) ;or
          ) ;and
        ) ;let
      ) ;and
    ) ;define

    ;; 最近一条携带有效 usage 的 assistant 消息的 usage（无则 #f）：
    ;; 全零占位消息结算时回退沿用，避免页脚上下文占比闪回 0.0%
    (define (%last-known-usage msgs)
      (let loop
        ((rest (reverse msgs)))
        (cond ((null? rest) #f)
              ((and (pi-assistant-message? (car rest))
                 (%usage-has-tokens? (pi-assistant-message-usage (car rest)))
               ) ;and
               (pi-assistant-message-usage (car rest))
              ) ;
              ((and (pair? (car rest))
                 (%usage-has-tokens? (pi-agent-assoc-val 'usage "usage" (car rest) '()))
               ) ;and
               (pi-agent-assoc-val 'usage "usage" (car rest) '())
              ) ;
              (else (loop (cdr rest)))
        ) ;cond
      ) ;let
    ) ;define

    ;; 结算响应 usage 全零/缺失时回填最近已知 usage：
    ;; 请求并未消耗上下文，沿用已知值可避免 message_usage 把占比打回 0.0%。
    ;; 仅作用于内存结算与事件上报，不改动落盘消息
    (define (%carry-last-usage resp msgs)
      (let* ((u (if (pi-assistant-message? resp)
                  (pi-assistant-message-usage resp)
                  (and (pair? resp) (pi-agent-assoc-val 'usage "usage" resp #f))
                ) ;if
             ) ;u
             (last (and (not (%usage-has-tokens? u)) (%last-known-usage msgs)))
            ) ;
        (cond ((not last) resp)
              ((pi-assistant-message? resp)
               (pi-assistant-message (pi-assistant-message-content resp)
                 :stop-reason   (pi-assistant-message-stop-reason resp)
                 :error-message (pi-assistant-message-error-message resp)
                 :usage         last
                 :timestamp     (pi-assistant-message-timestamp resp)
                 :provider      (pi-assistant-message-provider resp)
                 :model         (pi-assistant-message-model resp)
                 :api           (pi-assistant-message-api resp)
               ) ;pi-assistant-message
              ) ;
              ((pair? resp)
               (append
                 (remove
                   (lambda (x) (and (pair? x) (or (eq? (car x) 'usage) (equal? (car x) "usage"))))
                   resp
                 ) ;remove
                 (list (cons 'usage last))
               ) ;append
              ) ;
              (else resp)
        ) ;cond
      ) ;let*
    ) ;define

    (define* (pi-step-agent-turn config msgs system-prompt emit timeout request-fn)
      (let* ((eff-cfg (%resolve-effective-cfg config))
             (active-tools (pi-cfg-ref eff-cfg 'tools '()))
             (provider (pi-cfg-ref eff-cfg 'provider "google"))
             (on-stream-ev
               (if (procedure? emit)
                 (lambda (ev)
                   (let ((usage (pi-agent-assoc-val 'usage "usage" ev '())))
                     (emit 'message_update usage ev)
                   ) ;let
                 ) ;lambda
                 #f
               ) ;if
             ) ;on-stream-ev
             (raw-resp (request-fn provider eff-cfg msgs system-prompt
                         active-tools on-stream-ev timeout
                       ) ;request-fn
             ) ;raw-resp
             (resp (pi-agent-attach-cost raw-resp eff-cfg))
            ) ;
        (when (procedure? emit)
          (emit 'message_start resp)
          ;; 结算事件用回填后的副本；落盘历史（new-msgs）保留原始 usage
          (emit 'message_end (%carry-last-usage resp msgs))
        ) ;when
        (let* ((new-msgs (append msgs (list resp)))
               (stop-reason (if (pi-assistant-message? resp)
                              (pi-assistant-message-stop-reason resp)
                              (pi-agent-assoc-val 'stopReason "stopReason" resp "")
                            ) ;if
               ) ;stop-reason
               (content (if (pi-assistant-message? resp)
                          (pi-assistant-message-content resp)
                          (pi-agent-assoc-val 'content "content" resp '())
                        ) ;if
               ) ;content
               (tool-calls (pi-filter-tool-calls content))
              ) ;
          (values new-msgs stop-reason tool-calls resp)
        ) ;let*
      ) ;let*
    ) ;define*

    (define (pi-notify-turn-end emit assistant-msg tool-results)
      (when (procedure? emit)
        (emit 'turn_end assistant-msg tool-results)
      ) ;when
    ) ;define

    (define (pi-emit-agent-end emit final-msgs stop-reason config)
      (when (procedure? emit)
        (let* ((aborted? (equal? stop-reason "aborted"))
               (summary (pi-agent-session-cost-summary final-msgs config))
               (cost (cdr (assoc 'totalCost summary)))
               (savings (cdr (assoc 'totalSavings summary)))
              ) ;
          (emit 'agent_end final-msgs #f cost savings)
          (emit 'agent_settled aborted?)
        ) ;let*
      ) ;when
      ;; 同步桥接到扩展事件系统：payload 携带 final-msgs 供扩展统计 usage
      (let ((ext-emit (%ext-emit config)))
        (when ext-emit
          (ext-emit 'agent_end (list (cons 'messages final-msgs)))
        ) ;when
      ) ;let
    ) ;define

    (define (pi-finish-agent-turn new-msgs stop-reason tool-calls emit config resp)
      (let ((final-msgs
              (if (equal? stop-reason "length")
                (if (null? tool-calls)
                  new-msgs
                  (append new-msgs (pi-fail-tool-calls-length tool-calls emit))
                ) ;if
                new-msgs
              ) ;if
            ) ;final-msgs
           ) ;
        (pi-notify-turn-end emit resp #())
        (pi-emit-agent-end emit final-msgs stop-reason config)
        final-msgs
      ) ;let
    ) ;define

    (define (pi-emit-agent-error err-msg msgs emit config)
      (let* ((resp (pi-agent-attach-cost err-msg config))
             (final-msgs (append msgs (list resp)))
            ) ;
        (when (procedure? emit)
          (emit 'turn_start)
          (emit 'message_start resp)
          ;; 事件上报使用回填后的 resp；返回/落盘保留原始占位 usage
          (emit 'message_end (%carry-last-usage resp msgs))
          (emit 'turn_end resp #())
          (pi-emit-agent-end emit final-msgs "error" config)
        ) ;when
        final-msgs
      ) ;let*
    ) ;define

    (define (pi-maybe-compact compaction msgs)
      (if
        (and (pair? compaction)
          (procedure? (cdr (or (assoc 'compactor compaction) '(#f . #f))))
        ) ;and
        (let ((res ((cdr (assoc 'compactor compaction)) msgs)))
          (if (and (pair? res) (list? res)) res msgs)
        ) ;let
        msgs
      ) ;if
    ) ;define

    (define (pi-handle-tool-use new-msgs tool-calls emit timeout config resp)
      (let*-values (((tools-res terminated?)
                     (pi-execute-tool-calls-with-status tool-calls emit timeout config)
                    ) ;
                   ) ;
        (let* ((all-msgs (append new-msgs tools-res))
               (res-vec (pi-extract-tool-result-blocks all-msgs (length tools-res)))
              ) ;
          (pi-notify-turn-end emit resp res-vec)
          (values all-msgs terminated?)
        ) ;let*
      ) ;let*-values
    ) ;define

    (define (%make-max-turns-error)
      (pi-assistant-message '()
        :stop-reason   "error"
        :error-message "Maximum turns limit reached"
        :usage         '((input . 0) (output . 0) (total . 0))
      ) ;pi-assistant-message
    ) ;define

    (define (%make-session-timeout-error)
      (pi-assistant-message '()
        :stop-reason "error"
        :error-message
        "Session timeout exceeded: total execution deadline reached"
        :usage '((input . 0) (output . 0) (total . 0))
      ) ;pi-assistant-message
    ) ;define

    (define* (pi-resolve-turn-system-prompt system-prompt
               tool-calls
               (turn #f)
               (max-turns #f)
               (remaining-sec #f)
               (deadline-sec #f)
               (session-timeout #f)
             ) ;pi-resolve-turn-system-prompt
      (let ((base (if (procedure? system-prompt) (system-prompt tool-calls) system-prompt))
           ) ;
        (if (number? turn)
          (let ((warning (pi-budget-warning turn max-turns remaining-sec deadline-sec session-timeout)
                ) ;warning
               ) ;
            (if (string? warning) (string-append base "\n\n" warning) base)
          ) ;let
          base
        ) ;if
      ) ;let
    ) ;define*

    (define (%run-agent-turn config msgs compaction emit timeout request-fn
              system-prompt turn max-turns deadline-sec session-timeout
              last-tool-calls
            ) ;%run-agent-turn
      (let ((ext-emit (%ext-emit config)))
        (when ext-emit
          (ext-emit 'turn_start (list (cons 'turn turn)))
        ) ;when
        (let* ((msgs (pi-maybe-compact compaction msgs))
               (msgs (%maybe-inject-steering! msgs config emit))
               (rem-sec (if deadline-sec (- deadline-sec (pi-current-monotonic-seconds)) #f))
               (turn-sp (pi-resolve-turn-system-prompt system-prompt
                          last-tool-calls turn max-turns rem-sec deadline-sec
                          session-timeout
                        ) ;pi-resolve-turn-system-prompt
               ) ;turn-sp
              ) ;
          (let*-values (((new-msgs stop-reason tool-calls resp)
                         (pi-step-agent-turn config msgs turn-sp emit timeout request-fn)
                        ) ;
                       ) ;
            (if (equal? stop-reason "toolUse")
              (let*-values (((all-msgs terminated?)
                             (pi-handle-tool-use new-msgs tool-calls emit timeout config resp)
                            ) ;
                           ) ;
                (if terminated?
                  (list (cons 'action 'stop-check)
                    (cons 'msgs all-msgs)
                    (cons 'stop-reason "stop")
                    (cons 'tool-calls tool-calls)
                    (cons 'resp resp)
                  ) ;list
                  (list (cons 'action 'continue)
                    (cons 'msgs all-msgs)
                    (cons 'stop-reason "toolUse")
                    (cons 'tool-calls tool-calls)
                    (cons 'resp resp)
                  ) ;list
                ) ;if
              ) ;let*-values
              (let ((hard-stop? (or (equal? stop-reason "error") (equal? stop-reason "aborted"))))
                (list (cons 'action (if hard-stop? 'hard-stop 'stop-check))
                  (cons 'msgs new-msgs)
                  (cons 'stop-reason stop-reason)
                  (cons 'tool-calls tool-calls)
                  (cons 'resp resp)
                ) ;list
              ) ;let
            ) ;if
          ) ;let*-values
        ) ;let*
      ) ;let
    ) ;define

    (define (%stop-or-continue msgs stop-reason tool-calls emit config resp k)
      (let ((next-msgs (%natural-stop-continue msgs config emit)))
        (if next-msgs
          (k next-msgs)
          (pi-finish-agent-turn msgs stop-reason tool-calls emit config resp)
        ) ;if
      ) ;let
    ) ;define

    (define* (run-agent-loop config
               initial-messages
               system-prompt
               (emit #f)
               (timeout 600)
               (max-turns 0)
               (session-timeout 0)
               (compaction #f)
               (request-fn pi-request-provider-stream)
               (emit-initial? #t)
             ) ;run-agent-loop
      (when (procedure? emit)
        (emit 'agent_start)
        (emit 'turn_start)
        (when emit-initial?
          (for-each (lambda (m) (emit 'message_start m) (emit 'message_end m))
            initial-messages
          ) ;for-each
        ) ;when
      ) ;when
      ;; 桥接 agent_start 到扩展事件系统
      (let ((ext-emit (%ext-emit config)))
        (when ext-emit
          (ext-emit 'agent_start '())
        ) ;when
      ) ;let
      (let* ((start-sec (pi-current-monotonic-seconds))
             (deadline-sec (if (and (number? session-timeout) (> session-timeout 0))
                             (+ start-sec session-timeout)
                             #f
                           ) ;if
             ) ;deadline-sec
            ) ;
        (let loop
          ((msgs initial-messages) (turn 0) (last-tool-calls '()))
          (cond
            ;; 用户中止（ESC）：不再发起新一轮请求，直接以 aborted 结算；
            ;; 已在途的流式请求由 stream 层检查点中止。
            ;; 注意：pi-emit-agent-end 返回 emit 回调的结果（非消息列表），
            ;; 必须显式返回 msgs，否则下游 persist-new-messages! 会把
            ;; #t/#f 当消息列表处理而报 type-error
            ((pi-aborted?) (pi-emit-agent-end emit msgs "aborted" config) msgs)
            ((and (number? session-timeout) (< session-timeout 0))
             (pi-emit-agent-error (%make-session-timeout-error) msgs emit config)
            ) ;
            ((and deadline-sec (> (pi-current-monotonic-seconds) deadline-sec))
             (pi-emit-agent-error (%make-session-timeout-error) msgs emit config)
            ) ;
            ((and (> max-turns 0) (>= turn max-turns))
             (pi-emit-agent-error (%make-max-turns-error) msgs emit config)
            ) ;
            (else
              (let* ((decision (%run-agent-turn config msgs compaction emit
                                 timeout request-fn system-prompt turn max-turns
                                 deadline-sec session-timeout last-tool-calls
                               ) ;%run-agent-turn
                     ) ;decision
                     (d-msgs (cdr (assq 'msgs decision)))
                     (d-stop (cdr (assq 'stop-reason decision)))
                     (d-tc (cdr (assq 'tool-calls decision)))
                     (d-resp (cdr (assq 'resp decision)))
                    ) ;
                (cond
                 ((eq? (cdr (assq 'action decision)) 'continue)
                  (when (procedure? emit)
                    (emit 'turn_start)
                  ) ;when
                  (loop d-msgs (+ turn 1) d-tc)
                 ) ;
                 ((eq? (cdr (assq 'action decision)) 'hard-stop)
                  (pi-finish-agent-turn d-msgs d-stop d-tc emit config d-resp)
                 ) ;
                 (else
                   ;; 自然停止前轮询点：steering 优先，其次 follow-up
                   ;; （含工具批次 terminate 后的场景，对齐上游不阻断排队消息）
                   (%stop-or-continue d-msgs
                     d-stop
                     d-tc
                     emit
                     config
                     d-resp
                     (lambda (next) (loop next (+ turn 1) d-tc))
                   ) ;%stop-or-continue
                 ) ;else
                ) ;cond
              ) ;let*
            ) ;else
          ) ;cond
        ) ;let
      ) ;let*
    ) ;define*

  ) ;begin
) ;define-library
