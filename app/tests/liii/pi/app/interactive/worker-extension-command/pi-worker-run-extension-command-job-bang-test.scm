;; pi-worker-run-extension-command-job!
;; worker 的 extension_command job 分发：从注册表解析命令并执行；
;; 未知命令回投 error 事件并结算。
;;
;; 语法
;; ----
;; (pi-worker-run-extension-command-job! job parsed cfg sfile-box event-chan ensure-session-file)
;;
;; 参数
;; ----
;; job : pair?
;; (extension_command name args) 形式的任务。
;; parsed : alist?
;; worker CLI 参数。
;; cfg : alist?
;; worker 运行配置。
;; sfile-box : vector?
;; 会话文件盒（此处由 ensure-session-file 提供实际文件）。
;; event-chan : chan?
;; TUI 事件通道。
;; ensure-session-file : procedure?
;; 返回会话文件路径的 thunk。
;;
;; 返回值
;; ----
;; unspecified
;; 已注册命令执行其 handler 并结算；未知命令投递 extension_command_error
;; 与 agent_settled。命令名可带或不带前导斜杠。

(import (scheme base)
  (liii check)
  (liii go)
  (liii pi code core extensions)
  (liii pi app interactive worker-extension-command)
) ;import

(check-set-mode! 'report-failed)

(define (drain chan)
  (let loop ((acc '()))
    (let ((ev (chan-try-recv! chan #f)))
      (if ev (loop (cons ev acc)) (reverse acc))
    ) ;let
  ) ;let
) ;define

(define (make-no-files-command name)
  (make-extension-command-def name
    "probe"
    (lambda (args ctx) '((status . no-files) (message . "nothing to review")))
  ) ;make-extension-command-def
) ;define

;; 1. 注册命令（带斜杠名）：job 用不带斜杠名也可解析执行
(let ((chan (make-chan 16)))
  (register-command! (default-extension-registry) (make-no-files-command "/ext-job-probe"))
  (pi-worker-run-extension-command-job!
    (list 'extension_command "ext-job-probe" "")
    '() '() (vector #f) chan
    (lambda () #f)
  ) ;pi-worker-run-extension-command-job!
  (let ((events (drain chan)))
    (check (car (car events)) => 'extension_command_notice)
    (check (car (car (reverse events))) => 'agent_settled)
  ) ;let
) ;let

;; 2. 未知命令：投递 extension_command_error 与 agent_settled
(let ((chan (make-chan 16)))
  (pi-worker-run-extension-command-job!
    (list 'extension_command "definitely-not-registered-xyz" "")
    '() '() (vector #f) chan
    (lambda () #f)
  ) ;pi-worker-run-extension-command-job!
  (let ((events (drain chan)))
    (check (car (car events)) => 'extension_command_error)
    (check (car (car (reverse events))) => 'agent_settled)
  ) ;let
) ;let

(check-report)
