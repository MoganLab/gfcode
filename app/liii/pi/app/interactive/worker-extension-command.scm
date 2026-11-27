;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License

;; worker 的扩展命令执行：解析注册表中的命令、执行只读会话、
;; 处理 fallback 降级重试，并把 notice/error/report 事件回投给 app。
;; 独立成模块以避免 worker.scm 超出 max-file-lines / max-tree-depth 限制。
(define-library (liii pi app interactive worker-extension-command)
  (export pi-tui-run-extension-command! pi-worker-run-extension-command-job!)
  (import (scheme base)
    (scheme write)
    (liii path)
    (liii string)
    (liii pi code core extensions)
    (liii pi code modes flow)
    (liii pi app interactive worker-emit)
    (liii pi code core extension-result)
  ) ;import
  (begin

    (define (pi-tui-run-extension-command! command args parsed cfg sfile event-chan)
      (catch #t
        (lambda ()
          (let* ((handler (extension-command-def-handler command))
                 (ctx
                   (list (cons 'config cfg)
                     (cons 'cwd (path->string (path-cwd)))
                     ;; 命令若提供独立执行窗口，则 session 在该窗口内运行
                     ;; （如 code-review 用它抑制自动注入）；缺省直接执行
                     (cons 'run-isolated (lambda (thunk) (thunk)))
                   ) ;list
                 ) ;ctx
                 ;; fallback-runner 在 handler 调用前就位：命令结算回调可请求
                 ;; 一次降级重试（返回 review-retry + 新 prompt/on-finish）
                 (ctx
                   (append ctx
                     (list (cons 'fallback-runner
                             (lambda (prompt on-finish) (make-review-retry prompt on-finish))
                           ) ;cons
                     ) ;list
                   ) ;append
                 ) ;ctx
                 (result (handler args ctx))
                ) ;
            (cond
             ((review-error? result)
              (pi-tui-send-event! event-chan
                (list 'extension_command_error (review-error-message result))
              ) ;pi-tui-send-event!
             ) ;
             ((review-no-files? result)
              (pi-tui-send-event! event-chan
                (list 'extension_command_notice (review-no-files-message result))
              ) ;pi-tui-send-event!
             ) ;
             ((review-session-request? result)
              (%run-extension-session result ctx sfile event-chan)
             ) ;
             ;; handler 返回非 review-result（旧占位字符串/#f/异常值）：报错
             (else
               (pi-tui-send-event! event-chan
                 (list 'extension_command_error
                   (string-append "Command returned no session request: "
                     (extension-command-def-name command)
                   ) ;string-append
                 ) ;list
               ) ;pi-tui-send-event!
             ) ;else
            ) ;cond
          ) ;let*
        ) ;lambda
        (lambda (tag . err)
          (pi-tui-send-event! event-chan
            (list 'extension_command_error
              (string-append (object->string tag) ": " (object->string err))
            ) ;list
          ) ;pi-tui-send-event!
        ) ;lambda
      ) ;catch
      (pi-tui-send-event! event-chan '(agent_settled #f))
    ) ;define

    ;; 执行命令返回的会话请求；结算回调可请求一次降级重试（review-retry）：
    ;; 用命令提供的新 prompt/on-finish 再跑一次只读 session；
    ;; 重试结算不再接受 retry，避免循环
    (define (%run-extension-session result ctx sfile event-chan)
      (let ((notice (review-session-request-notice result)))
        (when notice
          (pi-tui-send-event! event-chan (list 'tps_report notice))
        ) ;when
      ) ;let
      (let ((response (%run-in-window result
                        ctx
                        (review-session-request-prompt result)
                        (review-session-request-on-finish result)
                        sfile
                        event-chan
                      ) ;%run-in-window
            ) ;response
           ) ;
        (let ((final
                (if (review-retry? response)
                  (begin
                    (pi-tui-send-event! event-chan
                      (list 'tps_report "Structured review failed; retrying with fallback prompt.")
                    ) ;pi-tui-send-event!
                    (%run-in-window result
                      ctx
                      (review-retry-prompt response)
                      (review-retry-on-finish response)
                      sfile
                      event-chan
                    ) ;%run-in-window
                  ) ;begin
                  response
                ) ;if
              ) ;final
             ) ;
          (cond
           ((review-error? final)
            (pi-tui-send-event! event-chan
              (list 'extension_command_error (review-error-message final))
            ) ;pi-tui-send-event!
           ) ;
           ((review-ok? final)
            (pi-tui-send-event! event-chan
              (list 'extension_command_report (review-ok-report final))
            ) ;pi-tui-send-event!
           ) ;
           ;; 结算返回非预期类型（如 retry 再重试）：不报告，仅结算
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%run-in-window result ctx prompt on-finish sfile event-chan)
     ((cdr (assoc 'run-isolated ctx))
      (lambda ()
        (run-session-flow (review-session-request-parsed result)
          (review-session-request-config result)
          prompt
          (make-tui-emit event-chan)
          on-finish
          sfile
          '()
          #f
        ) ;run-session-flow
      ) ;lambda
     ) ;
    ) ;define

    ;; worker 的 extension_command job 分发：从注册表解析命令并执行；
    ;; 未知命令回投 error 事件并结算。
    (define (pi-worker-run-extension-command-job! job parsed cfg sfile-box
              event-chan ensure-session-file
            ) ;pi-worker-run-extension-command-job!
      (let ((command
              (or (find-extension-command (default-extension-registry) (cadr job))
                (find-extension-command (default-extension-registry)
                  (string-append "/" (cadr job))
                ) ;find-extension-command
              ) ;or
            ) ;command
           ) ;
        (if command
          (let ((sfile (ensure-session-file)))
            (pi-tui-run-extension-command! command (caddr job) parsed cfg sfile event-chan)
          ) ;let
          (begin
            (pi-tui-send-event! event-chan
              (list 'extension_command_error
                (string-append "Unknown extension command: " (cadr job))
              ) ;list
            ) ;pi-tui-send-event!
            (pi-tui-send-event! event-chan '(agent_settled #f))
          ) ;begin
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
