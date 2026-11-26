;; pi-app-submit! 扩展命令分发
;; 验证已注册 slash command 进入 worker，不再作为普通文本提交。
;;
;; 语法
;; ----
;; (pi-app-submit! app text)
;;
;; 参数
;; ----
;; app : pi-app?
;; 带自定义 handler 的测试应用。
;; text : string?
;; 用户输入。
;;
;; 返回值
;; ----
;; any
;; 命令分发或普通消息提交结果。
;;
;; 错误行为
;; --------
;; busy 时只提示，不投递命令；未知 slash command 保持普通消息语义。

(import (scheme base)
  (liii check)
  (liii go)
  (liii tui)
  (liii pi agent queue)
  (liii pi code core extensions)
  (liii pi app interactive app)
  (liii pi app interactive app-submit)
) ;import

(check-set-mode! 'report-failed)

(let* ((vterm (make-virtual-terminal :width 80 :height 24))
       (submitted #f)
       (app (make-pi-app :terminal vterm :handler (lambda (a m) (set! submitted m))))
       (registry (make-extension-registry))
       (command (make-extension-command-def "/probe"
                  "probe"
                  (lambda (args ctx) '((status . no-files)))
                ) ;make-extension-command-def
       ) ;command
      ) ;
  (register-command! registry command)
  (set-default-extension-registry! registry)
  (pi-app-submit! app "/probe --staged")
  (let ((job (chan-try-recv! (pi-app-jobs-chan app) #f)))
    (check (and job (car job)) => 'extension_command)
    (check (and job (cadr job)) => "/probe")
    (check (and job (caddr job)) => "--staged")
  ) ;let
  (check submitted => #f)
  (check (editor-text (pi-app-editor app)) => "")
  (pi-queue-set-busy! (pi-app-queue app))
  (pi-app-submit! app "/probe")
  (check (chan-try-recv! (pi-app-jobs-chan app) #f) => #f)
  (set-default-extension-registry! #f)
) ;let*

(check-report)
