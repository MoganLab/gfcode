;; run-agent-loop
;; 全零 usage 结算消息的上下文回退：模型返回或错误占位消息 usage 全零时，
;; 结算响应回填最近一条已知 usage，避免 message_usage 把页脚占比打回 0.0%。
;;
;; 语法
;; ----
;; (run-agent-loop config initial-messages system-prompt (emit #f) (timeout 600)
;;   (max-turns 0) (session-timeout 0) (compaction #f)
;;   (request-fn pi-request-provider-stream) (emit-initial? #t))
;;
;; 参数
;; ----
;; 同 run-agent-loop-test.scm；本文件聚焦 usage 回退行为。
;;
;; 返回值
;; ----
;; list?，执行完成后的完整消息历史列表。
;; 注意：回退仅作用于内存结算与事件上报，落盘消息保留原始全零 usage。

(import (scheme base) (liii check) (liii pi ai message) (liii pi agent loop))

(check-set-mode! 'report-failed)

(define %known-usage '((input . 100) (output . 20) (totalTokens . 120)))

(define %zero-usage '((input . 0) (output . 0) (total . 0)))

;; 1. 第二轮响应 usage 全零：message_end 结算响应回填上一轮已知 usage
(let* ((round 0)
       (end-usages '())
       (emit
         (lambda (ev-type . args)
           (when (and (eq? ev-type 'message_end) (pair? args) (pi-assistant-message? (car args)))
             (set! end-usages (cons (pi-assistant-message-usage (car args)) end-usages))
           ) ;when
         ) ;lambda
       ) ;emit
       (mock-req
         (lambda (provider cfg msgs sp tools on-stream to)
           (set! round (+ round 1))
           (pi-assistant-message (list (list (cons 'type "text") (cons 'text "ok")))
             :stop-reason "stop"
             :usage       (if (= round 1) %known-usage %zero-usage)
           ) ;pi-assistant-message
         ) ;lambda
       ) ;mock-req
       (cfg '((tools) (provider . "google") (model-id . "m") (models-store)))
       ;; 第一轮后以 follow-up 注入驱动第二轮（无工具调用也可续跑）
       (follow-ups (list (list (pi-user-message "again"))))
       (cfg2
         (append cfg
           (list
             (cons 'get-follow-up-messages
               (lambda ()
                 (if (pair? follow-ups)
                   (let ((m (car follow-ups)))
                     (set! follow-ups (cdr follow-ups))
                     (list m)
                   ) ;let
                   '()
                 ) ;if
               ) ;lambda
             ) ;cons
           ) ;list
         ) ;append
       ) ;cfg2
       (res (run-agent-loop cfg2 (list (pi-user-message "hi")) "" emit 10 0 0 #f mock-req)
       ) ;res
      ) ;
  (check round => 2)
  ;; 第二轮结算事件（最新一条）的 usage 应回填为已知值
  (check (cdr (assoc 'input (car end-usages))) => 100)
  ;; 落盘历史保留原始全零 usage（会话恢复会自行跳过）
  (check
    (cdr (assoc 'input (pi-assistant-message-usage (list-ref res 3))))
    =>
    0
  ) ;check
) ;let*

;; 2. 会话超时错误占位（usage 全零）：结算沿用最近已知 usage
(let* ((end-usages '())
       (emit
         (lambda (ev-type . args)
           (when (and (eq? ev-type 'message_end) (pair? args) (pi-assistant-message? (car args)))
             (set! end-usages (cons (pi-assistant-message-usage (car args)) end-usages))
           ) ;when
         ) ;lambda
       ) ;emit
       (mock-req
         (lambda (provider cfg msgs sp tools on-stream to)
           (pi-assistant-message (list (list (cons 'type "text") (cons 'text "ok")))
             :stop-reason "stop"
             :usage       %known-usage
           ) ;pi-assistant-message
         ) ;lambda
       ) ;mock-req
       (cfg '((tools) (provider . "google") (model-id . "m") (models-store)))
       (history (list (pi-user-message "hi")
                  (pi-assistant-message '() :stop-reason "stop" :usage %known-usage)
                ) ;list
       ) ;history
       ;; session-timeout 为负数：立即以超时错误占位结算
       (res (run-agent-loop cfg history "" emit 10 0 -1 #f mock-req #f))
      ) ;
  (check (length end-usages) => 1)
  (check (cdr (assoc 'input (car end-usages))) => 100)
  ;; 落盘的错误占位消息仍为全零 usage
  (check
    (cdr (assoc 'input (pi-assistant-message-usage (list-ref res 2))))
    =>
    0
  ) ;check
) ;let*

;; 3. 无任何已知 usage 时：全零结算保持原样（首条消息即全零不误填）
(let* ((end-usages '())
       (emit
         (lambda (ev-type . args)
           (when (and (eq? ev-type 'message_end) (pair? args) (pi-assistant-message? (car args)))
             (set! end-usages (cons (pi-assistant-message-usage (car args)) end-usages))
           ) ;when
         ) ;lambda
       ) ;emit
       (mock-req (lambda (provider cfg msgs sp tools on-stream to)
                   (pi-assistant-message '() :stop-reason "stop" :usage %zero-usage)
                 ) ;lambda
       ) ;mock-req
       (cfg '((tools) (provider . "google") (model-id . "m") (models-store)))
       (res (run-agent-loop cfg (list (pi-user-message "hi")) "" emit 10 0 0 #f mock-req)
       ) ;res
      ) ;
  (check (cdr (assoc 'input (car end-usages))) => 0)
) ;let*

(check-report)
