;; pi-tui-run-extension-command!
;; worker 执行扩展命令：调用 handler，将结果转换为 TUI 事件；
;; 携带 session 请求时经 run-session-flow 执行并回传报告或错误。
;;
;; 语法
;; ----
;; (pi-tui-run-extension-command! command args parsed cfg sfile event-chan)
;;
;; 参数
;; ----
;; command : extension-command-def?
;; 已解析的扩展命令定义。
;; args : string?
;; 命令原始参数。
;; parsed : alist?
;; worker CLI 参数。
;; cfg : alist?
;; worker 运行配置。
;; sfile : string? | #f
;; 会话文件。
;; event-chan : chan?
;; TUI 事件通道。
;;
;; 返回值
;; ----
;; unspecified
;; 事件通道收到 extension_command_error / extension_command_notice /
;; extension_command_report，随后必发 agent_settled。
;;
;; 错误行为
;; --------
;; handler 抛出异常或返回非 session 请求时投递可读错误，不中断 worker。

(import (scheme base)
  (liii check)
  (liii go)
  (liii path)
  (liii pi code core extensions)
  (liii pi app interactive worker)
) ;import

(check-set-mode! 'report-failed)

(define (drain chan)
  (let loop ((acc '()))
    (let ((ev (chan-try-recv! chan #f)))
      (if ev (loop (cons ev acc)) (reverse acc))
    ) ;let
  ) ;let
) ;define

;; 1. no-files handler：投递 notice 与 agent_settled
(let* ((chan (make-chan 16))
       (command (make-extension-command-def "/probe"
                  "probe"
                  (lambda (args ctx) '((status . no-files) (message . "nothing to review")))
                ) ;make-extension-command-def
       ) ;command
      ) ;
  (pi-tui-run-extension-command! command "" '() '() #f chan)
  (let ((events (drain chan)))
    (check (car (car events)) => 'extension_command_notice)
    (check (cadr (car events)) => "nothing to review")
    (check (car (car (reverse events))) => 'agent_settled)
  ) ;let
) ;let*

;; 2. handler 抛异常：投递可读错误而非崩溃
(let* ((chan (make-chan 16))
       (command (make-extension-command-def "/boom"
                  "boom"
                  (lambda (args ctx) (error 'value-error "bad args"))
                ) ;make-extension-command-def
       ) ;command
      ) ;
  (pi-tui-run-extension-command! command "" '() '() #f chan)
  (let ((events (drain chan)))
    (check (car (car events)) => 'extension_command_error)
    (check (car (car (reverse events))) => 'agent_settled)
  ) ;let
) ;let*

;; 3. 非 session 请求返回值（如旧占位字符串）：投递错误而非静默丢弃
(let* ((chan (make-chan 16))
       (command (make-extension-command-def "/legacy"
                  "legacy"
                  (lambda (args ctx) "not-a-request")
                ) ;make-extension-command-def
       ) ;command
      ) ;
  (pi-tui-run-extension-command! command "" '() '() #f chan)
  (check (car (car (drain chan))) => 'extension_command_error)
) ;let*

;; 4. session 请求：session-timeout=-1 立即错误结算，投递错误与 agent_settled
(let* ((chan (make-chan 16))
       (sfile (path->string (path-join (path-temp-dir) "pi-ext-cmd-test.jsonl")))
       (command (make-extension-command-def "/review"
                  "review"
                  (lambda (args ctx)
                    (list (cons 'status 'ok)
                      (cons 'parsed '((session-timeout . -1) (no-skills . #t)))
                      (cons 'config
                        (list (cons 'tools '())
                          (cons 'provider "google")
                          (cons 'config-dir (path->string (path-temp-dir)))
                        ) ;list
                      ) ;cons
                      (cons 'prompt "review this")
                      (cons 'on-finish
                        (lambda (msgs) '((status . ok) (report . "report-text")))
                      ) ;cons
                    ) ;list
                  ) ;lambda
                ) ;make-extension-command-def
       ) ;command
      ) ;
  (pi-tui-run-extension-command! command "" '() '() sfile chan)
  (let ((events (drain chan)))
    (check (car (car (reverse events))) => 'agent_settled)
    (check-true
      (let loop ((rest events))
        (cond ((null? rest) #f)
              ((eq? (car (car rest)) 'extension_command_error) #t)
              (else (loop (cdr rest)))
        ) ;cond
      ) ;let
    ) ;check-true
  ) ;let
) ;let*

(check-report)
