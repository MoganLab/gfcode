;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; worker 事件桥：安全发送助手 + 错误文本提取 + agent 会话事件到 TUI 卡片事件的翻译
(define-library (liii pi app interactive worker-emit)
  (export pi-tui-send-event! %assistant-error-text make-tui-emit)
  (import (scheme base) (liii go) (liii string) (liii pi code modes output))
  (begin

    ;; 安全带超时的事件发送，防止 channel 堵塞导致 worker 永久卡死
    (define (pi-tui-send-event! ch ev)
      (catch #t (lambda () (chan-send! ch ev 2000)) (lambda (t . a) #f))
    ) ;define

    ;; 错误结算辅助：stopReason=error 的 assistant 消息返回应上屏的错误文本
    ;; （errorMessage 缺省或空白时兜底 "Error"，对齐上游 errorMessage || "Error"），
    ;; 非 error 结算返回 #f
    (define (%assistant-error-text msg)
      (let* ((stop-reason (pi-message-field msg 'stopReason ""))
             (err-msg (pi-message-field msg 'errorMessage #f))
            ) ;
        (and (equal? stop-reason "error")
          (if
            (and (string? err-msg) (not (string-null? (string-trim-both err-msg))))
            err-msg
            "Error"
          ) ;if
        ) ;and
      ) ;let*
    ) ;define

    ;; 返回 (剩余缓冲 . 完整行列表)，由事件桥统一投递并更新闭包缓冲。
    (define (%take-thinking-lines text)
      (let ((newline-at (string-index text #\newline)))
        (if (not newline-at)
          (cons text '())
          (let ((rest (%take-thinking-lines (substring text (+ newline-at 1) (string-length text)))
                ) ;rest
               ) ;
            (cons (car rest) (cons (substring text 0 newline-at) (cdr rest)))
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    (define (%flush-thinking-lines! event-chan lines)
      (for-each (lambda (line)
                  (pi-tui-send-event! event-chan (list 'assistant_thinking_line line))
                ) ;lambda
        lines
      ) ;for-each
    ) ;define

    (define (%thinking-delta event-chan buffer ev)
      (let ((delta-entry (assoc 'delta ev)))
        (if (and delta-entry (string? (cdr delta-entry)))
          (let* ((split (%take-thinking-lines (string-append buffer (cdr delta-entry))))
                 (lines (cdr split))
                ) ;
            (%flush-thinking-lines! event-chan lines)
            (car split)
          ) ;let*
          buffer
        ) ;if
      ) ;let
    ) ;define

    (define (%thinking-end event-chan buffer)
      (unless (string-null? (string-trim-both buffer))
        (%flush-thinking-lines! event-chan (list buffer))
      ) ;unless
      ;; 无条件投递块结束信号：UI 据此关闭当前卡片，
      ;; 下一个块（下一 turn 或 interleaved）的行落到新卡片
      (pi-tui-send-event! event-chan '(assistant_thinking_end))
      ""
    ) ;define

    (define (%text-delta event-chan text-streamed? ev)
      (let ((delta-entry (assoc 'delta ev)))
        (if
          (and delta-entry
            (string? (cdr delta-entry))
            (not (string-null? (cdr delta-entry)))
          ) ;and
          (let ((delta (cdr delta-entry)))
            (pi-tui-send-event! event-chan (list 'assistant_text_delta delta))
            (or text-streamed? (not (string-null? (string-trim-both delta))))
          ) ;let
          text-streamed?
        ) ;if
      ) ;let
    ) ;define

    (define (%text-end event-chan text-streamed?)
      (when text-streamed?
        (pi-tui-send-event! event-chan '(assistant_text_end))
      ) ;when
      text-streamed?
    ) ;define

    ;; 返回 (新 thinking-line-buffer . 新 text-streamed?)
    (define (%message-update event-chan buffer text-streamed? ev)
      (let* ((type-entry (assoc 'type ev)) (stream-type (and type-entry (cdr type-entry))))
        (cond ((equal? stream-type "thinking_delta")
               (cons (%thinking-delta event-chan buffer ev) text-streamed?)
              ) ;
              ((equal? stream-type "thinking_end")
               (cons (%thinking-end event-chan buffer) text-streamed?)
              ) ;
              ((equal? stream-type "text_delta")
               (cons buffer (%text-delta event-chan text-streamed? ev))
              ) ;
              ((equal? stream-type "text_end")
               (cons buffer (%text-end event-chan text-streamed?))
              ) ;
              (else (cons buffer text-streamed?))
        ) ;cond
      ) ;let*
    ) ;define

    ;; 将 agent 会话事件翻译为 TUI 卡片事件并投递到 event-chan（生产与测试共用）
    ;; context-window：可为数字（当前模型上下文窗口 Token 数）、
    ;; 过程（返回本次有效窗口，随 effective-cfg 动态变化）或 #f。
    ;; 随 message_usage 事件投递给前端用于换算上下文占比。
    (define (make-tui-emit event-chan . opt-window)
      (let ((window-arg (if (pair? opt-window) (car opt-window) #f))
            (call-args-map '())
            (thinking-line-buffer "")
            (text-streamed? #f)
            ;; all-in-one 实际节点上报的窗口覆盖：只作用于发出它的那一次
            ;; all-in-one 请求；后续 effective-cfg 改变时随 agent_settled 清除，
            ;; 避免污染普通模型或另一条链的 usage
            (active-node-window #f)
           ) ;
        (define (current-window)
          (or active-node-window (if (procedure? window-arg) (window-arg) window-arg))
        ) ;define
        (lambda (event-type . args)
          (cond
            ;; provider 流式 thinking 与正文增量：
            ;; thinking 跨增量缓冲按行投递；正文增量即时投递；块结束发结束信号
            ((eq? event-type 'message_update)
             (when (>= (length args) 2)
               (let ((res (%message-update event-chan thinking-line-buffer text-streamed? (cadr args))
                     ) ;res
                    ) ;
                 (set! thinking-line-buffer (car res))
                 (set! text-streamed? (cdr res))
               ) ;let
             ) ;when
            ) ;
            ;; 工具开始：立即创建 pending 卡片，并记录参数供结束事件查找
            ((eq? event-type 'tool_execution_start)
             (when (>= (length args) 3)
               (let ((id (car args)) (name (cadr args)) (call-args (caddr args)))
                 (set! call-args-map (cons (cons id call-args) call-args-map))
                 (pi-tui-send-event! event-chan (list 'tool_execution_start id name call-args))
               ) ;let
             ) ;when
            ) ;
            ;; 流式部分结果：保留调用 id，主线程据此更新原卡片
            ((eq? event-type 'tool_execution_update)
             (when (>= (length args) 4)
               (pi-tui-send-event! event-chan
                 (list 'tool_execution_update (car args) (cadr args) (caddr args) (cadddr args))
               ) ;pi-tui-send-event!
             ) ;when
            ) ;
            ;; 工具执行完成
            ((eq? event-type 'tool_execution_end)
             (let* ((id (if (pair? args) (car args) ""))
                    (name (if (> (length args) 1) (cadr args) "tool"))
                    (raw-res (if (> (length args) 2) (caddr args) ""))
                    (is-err? (if (> (length args) 3) (cadddr args) #f))
                    (call-args
                      (let ((entry (assoc id call-args-map)))
                        (if entry (cdr entry) '())
                      ) ;let
                    ) ;call-args
                    (duration-ms (and (> (length args) 4) (list-ref args 4)))
                   ) ;
               (pi-tui-send-event! event-chan
                 (list 'tool_execution_end id name call-args is-err? raw-res duration-ms)
               ) ;pi-tui-send-event!
             ) ;let*
            ) ;
            ;; 消息回复完成
            ((eq? event-type 'message_end)
             (when (pair? args)
               (let* ((msg (car args))
                      (role (pi-message-field msg 'role ""))
                      (content (pi-message-field msg 'content '()))
                      (text (pi-content-text content))
                      (err-text (%assistant-error-text msg))
                      (usage (pi-message-field msg 'usage '()))
                     ) ;
                 (when (and (equal? role "assistant") (pair? usage))
                   (pi-tui-send-event! event-chan (list 'message_usage usage (current-window)))
                 ) ;when
                 (let ((was-streamed? (and (equal? role "assistant") text-streamed?)))
                   (when was-streamed?
                     (pi-tui-send-event! event-chan '(assistant_text_end))
                     (set! text-streamed? #f)
                   ) ;when
                   ;; 若本条消息未通过 text_delta 流式输出（如测试或非流式返回），兜底整段投递
                   (when
                     (and (equal? role "assistant")
                       (not was-streamed?)
                       (not (string-null? (string-trim-both text)))
                     ) ;and
                     (pi-tui-send-event! event-chan (list 'assistant_text text))
                   ) ;when
                 ) ;let
                 ;; 错误结算（对齐上游 message_end 渲染 errorMessage）：
                 ;; stopReason=error 时转为 error 卡片事件，保证用户可见
                 (when (and (equal? role "assistant") err-text)
                   (pi-tui-send-event! event-chan (list 'error err-text))
                 ) ;when
               ) ;let*
             ) ;when
            ) ;
            ;; 上下文重建（自动压缩）：通知前端占比转为未知
            ((eq? event-type 'compaction)
             (pi-tui-send-event! event-chan (list 'compaction))
            ) ;
            ;; all-in-one 交接完成：携带当前实际节点（provider model thinking-level）
            ;; 实际节点窗口仅用于本次请求的 usage 换算，优先级高于本次 effective-cfg
            ;; 的模型窗口；切换模型后随 agent_settled 清除，避免污染普通模型
            ((eq? event-type 'active_node)
             (when (pair? args)
               (let ((node (car args)))
                 (when (pair? node)
                   (when (and (>= (length node) 4) (number? (list-ref node 3)))
                     (set! active-node-window (list-ref node 3))
                   ) ;when
                   (pi-tui-send-event! event-chan (list 'active_node node))
                 ) ;when
               ) ;let
             ) ;when
            ) ;
            ;; 重试提示，转为卡片而非污染终端
            ((eq? event-type 'retry)
             (when (pair? args)
               (pi-tui-send-event! event-chan (list 'retry (car args)))
             ) ;when
            ) ;
            ((memq event-type '(recovery_wait recovery_tick recovery_retry
                                 recovery_end))
             (pi-tui-send-event! event-chan (cons event-type args))
            ) ;
            ;; 显式思考等级被节点能力收敛：一次状态卡片，不进会话消息
            ((eq? event-type 'thinking_clamp)
             (when (pair? args)
               (pi-tui-send-event! event-chan (list 'thinking_clamp (car args)))
             ) ;when
            ) ;
            ;; 任务全部结算完成：携带 aborted 标志（主线程据此上屏 Aborted 提示）
            ;; 同时清除 all-in-one 实际节点窗口覆盖，避免污染下一条消息
            ((eq? event-type 'agent_settled)
             (set! text-streamed? #f)
             (set! active-node-window #f)
             (pi-tui-send-event! event-chan
               (list 'agent_settled (and (pair? args) (car args)))
             ) ;pi-tui-send-event!
            ) ;
            (else #t)
          ) ;cond
        ) ;lambda
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
