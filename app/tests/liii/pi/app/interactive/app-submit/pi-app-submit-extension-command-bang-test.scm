;; pi-app-submit-extension-command!
;; 把已注册的 slash command 投递为 worker 的 extension_command job，不作为普通文本提交。
;;
;; 语法
;; ----
;; (pi-app-submit-extension-command! app command args)
;;
;; 参数
;; ----
;; app : pi-app?
;; 带自定义 handler 的测试应用。
;; command : extension-command-def?
;; 已注册的扩展命令定义。
;; args : string?
;; 命令原始参数。
;;
;; 返回值
;; ----
;; #t
;; 空闲时向 jobs-chan 投递 (extension_command name args) 并清空编辑器；
;; busy 时只提示，不投递命令。

(import (scheme base)
  (liii check)
  (liii go)
  (liii tui)
  (liii pi agent queue)
  (liii pi code core extensions)
  (liii pi app interactive app)
  (liii pi app interactive app-submit)
  (liii pi code core extension-result)
) ;import

(check-set-mode! 'report-failed)

(let* ((vterm (make-virtual-terminal :width 80 :height 24))
       (submitted #f)
       (app (make-pi-app :terminal vterm :handler (lambda (a m) (set! submitted m))))
       (command
         (make-extension-command-def "/probe"
           "probe"
           (lambda (args ctx) (make-review-no-files #f #f))
         ) ;make-extension-command-def
       ) ;command
      ) ;
  (pi-app-submit-extension-command! app command "--staged")
  (let ((job (chan-try-recv! (pi-app-jobs-chan app) #f)))
    (check (and job (car job)) => 'extension_command)
    (check (and job (cadr job)) => "/probe")
    (check (and job (caddr job)) => "--staged")
  ) ;let
  (check submitted => #f)
  (check (editor-text (pi-app-editor app)) => "")
  ;; busy：只提示，不再投递
  (pi-queue-set-busy! (pi-app-queue app))
  (pi-app-submit-extension-command! app command "")
  (check (chan-try-recv! (pi-app-jobs-chan app) #f) => #f)
) ;let*

(check-report)
