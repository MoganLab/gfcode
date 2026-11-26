;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code modes verbose)
  (import (scheme base)
    (scheme write)
    (liii base)
    (liii string)
    (liii list)
    (liii json)
    (liii pi code event)
    (liii pi ai message)
    (liii pi ai time)
    (liii pi code modes output)
  ) ;import
  (export display-agent-event display-verbose-event make-verbose-emitter
    handle-verbose-result verbose-thinking-ping-due?
  ) ;export
  (begin

    (define (%substring-index pattern str)
      (let ((plen (string-length pattern)) (slen (string-length str)))
        (let loop
          ((i 0))
          (cond ((> (+ i plen) slen) #f)
                ((string=? (substring str i (+ i plen)) pattern) i)
                (else (loop (+ i 1)))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%prop-ref obj key-sym key-str default)
      (if (not (pair? obj))
        default
        (let ((p (or (assoc key-str obj) (assoc key-sym obj))))
          (if p (cdr p) default)
        ) ;let
      ) ;if
    ) ;define

    ;; 把事件里的 message 字段归一化为 alist：emit 传入的可能是
    ;; <pi-assistant-message>/<pi-user-message> record（JSON 序列化路径
    ;; 由 %normalize-json-value 处理，本模块需自行转换）。
    (define (%normalize-message msg)
      (cond ((pi-message? msg) (pi-message->json msg))
            ((pair? msg) msg)
            (else '())
      ) ;cond
    ) ;define

    (define (%prop-string obj key-sym key-str default)
      (let ((v (%prop-ref obj key-sym key-str default)))
        (if (string? v) v default)
      ) ;let
    ) ;define

    (define (%prop-boolean obj key-sym key-str default)
      (let ((v (%prop-ref obj key-sym key-str default)))
        (cond ((boolean? v) v)
              ((or (eq? v 'true) (equal? v "true")) #t)
              ((or (eq? v 'false) (equal? v "false")) #f)
              (else default)
        ) ;cond
      ) ;let
    ) ;define

    ;; turn-box 结构: (轮次 消息缓冲 是否已打印过本条消息的行 思考状态盒)
    ;; 思考状态盒为 vector #(active? start-ms last-ping-ms)，由 ensure 惰性补齐
    (define (ensure-message-slots turn-box)
      (when (null? (cdr turn-box))
        (set-cdr! turn-box (list "" #f #f))
      ) ;when
      (when (null? (cddr turn-box))
        (set-cdr! (cdr turn-box) (list #f #f))
      ) ;when
      (when (null? (cdddr turn-box))
        (set-cdr! (cddr turn-box) (list (vector #f 0 0)))
      ) ;when
    ) ;define

    ;; 思考进度行间隔（毫秒）：正在思考中每 60s 提示一次
    (define %thinking-ping-interval-ms 60000)

    (define (verbose-thinking-ping-due? elapsed-ms)
      (>= elapsed-ms %thinking-ping-interval-ms)
    ) ;define

    (define (%format-elapsed-ms ms)
      (string-append (number->string (floor (/ ms 1000))) "s")
    ) ;define

    (define (%thinking-box turn-box)
      (cadddr turn-box)
    ) ;define

    (define (%handle-thinking-start! turn-box port)
      (let ((tb (%thinking-box turn-box)))
        (when (vector? tb)
          (vector-set! tb 0 #t)
          (vector-set! tb 1 (pi-current-monotonic-millis))
          (vector-set! tb 2 (pi-current-monotonic-millis))
        ) ;when
      ) ;let
      (display "🧠 开始思考…\n" port)
    ) ;define

    (define (%handle-thinking-delta! turn-box port)
      (let ((tb (%thinking-box turn-box)))
        ;; 不显示具体思考内容；仅按间隔提示仍在思考
        (when (and (vector? tb) (vector-ref tb 0))
          (let* ((now (pi-current-monotonic-millis)) (since-last (- now (vector-ref tb 2))))
            (when (verbose-thinking-ping-due? since-last)
              (vector-set! tb 2 now)
              (let ((elapsed (- now (vector-ref tb 1))))
                (display (string-append "🧠 仍在思考…（已 "
                           (%format-elapsed-ms elapsed)
                           "）\n"
                         ) ;string-append
                  port
                ) ;display
              ) ;let
            ) ;when
          ) ;let*
        ) ;when
      ) ;let
    ) ;define

    (define (%handle-thinking-end! turn-box port)
      (let ((tb (%thinking-box turn-box)))
        (when (and (vector? tb) (vector-ref tb 0))
          (let ((elapsed (- (pi-current-monotonic-millis) (vector-ref tb 1))))
            (vector-set! tb 0 #f)
            (display (string-append "🧠 思考完成（用时 "
                       (%format-elapsed-ms elapsed)
                       "）\n"
                     ) ;string-append
              port
            ) ;display
          ) ;let
        ) ;when
      ) ;let
    ) ;define

    (define (display-message-line turn-box line port)
      ;; 本条消息的第一行带 💬 前缀，续行直接输出
      (display (if (caddr turn-box)
                 (string-append line "\n")
                 (string-append "💬 " line "\n")
               ) ;if
        port
      ) ;display
    ) ;define

    (define (flush-message-lines turn-box port)
      ;; 合并增量后，遇到 \n 就立即打印完整行
      (let loop
        ()
        (let* ((buf (cadr turn-box)) (idx (%substring-index "\n" buf)))
          (when idx
            (let ((line (substring buf 0 idx))
                  (rest (substring buf (+ idx 1) (string-length buf)))
                 ) ;
              (display-message-line turn-box line port)
              (set-car! (cddr turn-box) #t)
              (set-car! (cdr turn-box) rest)
              (loop)
            ) ;let
          ) ;when
        ) ;let*
      ) ;let
    ) ;define

    (define (flush-message-tail turn-box port)
      ;; message 结束时打印剩余未换行的尾部，并复位缓冲
      (let ((message (string-trim-both (cadr turn-box))))
        (when (> (string-length message) 0)
          (display-message-line turn-box message port)
        ) ;when
        (set-car! (cdr turn-box) "")
        (set-car! (cddr turn-box) #f)
      ) ;let
    ) ;define

    (define (%handle-turn-start! turn-box port)
      (set-car! turn-box (+ (car turn-box) 1))
      (set-car! (cdr turn-box) "")
      (set-car! (cddr turn-box) #f)
      (let ((tb (%thinking-box turn-box)))
        (when (vector? tb)
          (vector-set! tb 0 #f)
          (vector-set! tb 1 0)
          (vector-set! tb 2 0)
        ) ;when
      ) ;let
      ;; 第 2 轮起在 💡 上方补一行空行，与第 1 轮前的空行视觉一致
      (when (> (car turn-box) 1)
        (display "\n" port)
      ) ;when
      (display (format #f "💡 [Turn ~a]\n" (car turn-box)) port)
    ) ;define

    (define (%handle-tool-start! ev port)
      (let ((tool (%prop-string ev 'toolName "toolName" "tool"))
            (args (%prop-ref ev 'args "args" '()))
           ) ;
        (cond
         ((string=? tool "bash")
          (let ((cmd (%prop-string args 'command "command" "")))
            (display (format #f "💻 [bash] ~a\n" cmd) port)
          ) ;let
         ) ;
         ((member tool '("read" "edit" "write"))
          (let ((p (%prop-string args 'path "path" "")))
            (display (format #f "📄 [~a] ~a\n" tool p) port)
          ) ;let
         ) ;
         (else (display (format #f "🔧 [~a]\n" tool) port))
        ) ;cond
      ) ;let
    ) ;define

    (define (%handle-tool-end! ev port)
      (let ((tool (%prop-string ev 'toolName "toolName" ""))
            (is-err (%prop-boolean ev 'isError "isError" #f))
           ) ;
        (display (format #f "   └─ [~a] ~a\n" tool (if is-err "❌ 失败" "✅ 完成"))
          port
        ) ;display
      ) ;let
    ) ;define

    (define (%handle-message-start! ev turn-box)
      ;; 实测 pi (JSON mode) 的 wire 顺序：assistant 的 message_update
      ;; 增量先于 message_start(assistant) 到达，因此仅对 user 角色
      ;; 重置缓冲，避免清空尚未 flush 的助手文本（toolResult 同理）。
      (let* ((msg (%normalize-message (%prop-ref ev 'message "message" '())))
             (role (%prop-string msg 'role "role" ""))
            ) ;
        (when (string=? role "user")
          (set-car! (cdr turn-box) "")
          (set-car! (cddr turn-box) #f)
        ) ;when
      ) ;let*
    ) ;define

    (define (%handle-message-update! ev turn-box port)
      (let* ((msg-ev (%prop-ref ev 'assistantMessageEvent "assistantMessageEvent" '()))
             (ev-type (%prop-string msg-ev 'type "type" ""))
            ) ;
        (cond ((string=? ev-type "thinking_start") (%handle-thinking-start! turn-box port))
              ((string=? ev-type "thinking_delta") (%handle-thinking-delta! turn-box port))
              ((string=? ev-type "thinking_end") (%handle-thinking-end! turn-box port))
              ((string=? ev-type "text_delta")
               (let ((delta (%prop-string msg-ev 'delta "delta" "")))
                 (set-car! (cdr turn-box) (string-append (cadr turn-box) delta))
                 (flush-message-lines turn-box port)
               ) ;let
              ) ;
              (else #f)
        ) ;cond
      ) ;let*
    ) ;define

    (define (%handle-message-end! ev turn-box port)
      (let* ((msg (%normalize-message (%prop-ref ev 'message "message" '())))
             (role (%prop-string msg 'role "role" ""))
             (stop-reason (%prop-string msg 'stopReason "stopReason" ""))
             (err-msg (%prop-string msg 'errorMessage "errorMessage" ""))
            ) ;
        ;; 流式思考未正常结束（如请求被截断/中断）时兜底收尾，
        ;; 避免思考状态悬挂到下一轮
        (let ((tb (%thinking-box turn-box)))
          (when (and (vector? tb) (vector-ref tb 0))
            (%handle-thinking-end! turn-box port)
          ) ;when
        ) ;let
        (when (and (string=? role "assistant")
                (or (string=? stop-reason "error") (string=? stop-reason "aborted"))
              ) ;and
          (display (format #f
                     "❌ [error] ~a\n"
                     (if (string-null? err-msg) (string-append "Request " stop-reason) err-msg)
                   ) ;format
            port
          ) ;display
        ) ;when
        (when (string=? role "assistant")
          (when (and (not (caddr turn-box)) (string-null? (cadr turn-box)))
            (let* ((content (%prop-ref msg 'content "content" '()))
                   (txt (pi-content-text content))
                  ) ;
              (when (and (string? txt) (not (string-null? txt)))
                (set-car! (cdr turn-box) txt)
                (flush-message-lines turn-box port)
              ) ;when
            ) ;let*
          ) ;when
        ) ;when
      ) ;let*
      (flush-message-tail turn-box port)
    ) ;define

    (define*
      (display-agent-event ev
        (line "")
        (turn-box (list 0 "" #f (vector #f 0 0)))
        (port (current-output-port))
      ) ;display-agent-event
      (let ((actual-ev
              (cond ((pi-event? ev) (pi-event->json ev))
                    ((string? ev) (catch #t (lambda () (string->json ev)) (lambda _ #f)))
                    ((pair? ev) ev)
                    (else #f)
              ) ;cond
            ) ;actual-ev
           ) ;
        (when (pair? actual-ev)
          (let ((t (%prop-string actual-ev 'type "type" "")))
            (ensure-message-slots turn-box)
            (cond ((string=? t "turn_start") (%handle-turn-start! turn-box port))
                  ((string=? t "tool_execution_start") (%handle-tool-start! actual-ev port))
                  ((string=? t "tool_execution_end") (%handle-tool-end! actual-ev port))
                  ((string=? t "message_start") (%handle-message-start! actual-ev turn-box))
                  ((string=? t "message_update")
                   (%handle-message-update! actual-ev turn-box port)
                  ) ;
                  ((string=? t "message_end") (%handle-message-end! actual-ev turn-box port))
                  ((string=? t "agent_end")
                   (flush-message-tail turn-box port)
                   (display "🏁 [pi] Agent 本阶段结束\n" port)
                  ) ;
            ) ;cond
          ) ;let
        ) ;when
      ) ;let
    ) ;define*

    (define* (display-verbose-event ev turn-box (port (current-output-port)))
      (display-agent-event ev "" turn-box port)
    ) ;define*

    (define* (make-verbose-emitter (port #f))
      (let ((turn-box (list 0 "" #f (vector #f 0 0))))
        (lambda (ev-type . args)
          (let ((ev (pi-build-json-event ev-type args)) (p (or port (current-output-port))))
            (when ev
              (display-agent-event (pi-event->json ev) "" turn-box p)
            ) ;when
          ) ;let
        ) ;lambda
      ) ;let
    ) ;define*

    (define* (handle-verbose-result last-msg (port (current-output-port)))
      (if (not (or (pair? last-msg) (pi-message? last-msg)))
        (begin
          (display-stderr "Warning: No assistant response received")
          0
        ) ;begin
        (let* ((msg (if (pi-message? last-msg) (pi-message->json last-msg) last-msg))
               (stop-reason (cdr (or (assoc 'stopReason msg) (assoc "stopReason" msg) '(#f
                                                                                        . "stop")))
               ) ;stop-reason
               (err-msg (cdr (or (assoc 'errorMessage msg) (assoc "errorMessage" msg) '(#f
                                                                                        . #f)))
               ) ;err-msg
              ) ;
          (cond
           ((or (string=? stop-reason "error") (string=? stop-reason "aborted"))
            (display-stderr (or err-msg (string-append "Request " stop-reason)))
            1
           ) ;
           ((string=? stop-reason "length")
            (display-stderr "Response was truncated: the model reached its output token limit."
            ) ;display-stderr
            1
           ) ;
           (else 0)
          ) ;cond
        ) ;let*
      ) ;if
    ) ;define*

  ) ;begin
) ;define-library
