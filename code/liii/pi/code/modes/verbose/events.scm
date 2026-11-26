;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code modes verbose events)
  (import (scheme base)
    (scheme write)
    (liii list)
    (liii json)
    (liii pi ai message)
    (liii pi code event)
    (liii pi code modes output)
    (liii pi code modes verbose common)
    (liii pi code modes verbose state)
    (liii pi code modes verbose thinking)
    (liii pi code modes verbose message)
  ) ;import
  (export display-agent-event display-verbose-event make-verbose-emitter
    handle-verbose-result
  ) ;export
  (begin

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
