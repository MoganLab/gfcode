;; pi-extension-notify
;; 触发已 arm 的通知回调；未 arm 时返回 #f。
;;
;; 语法
;; ----
;; (pi-extension-notify message)
;;
;; 参数
;; ----
;; message : any
;; 通知内容。
;;
;; 返回值
;; ----
;; any
;; 已 arm 时返回回调的执行结果，否则返回 #f。

(import (scheme base) (liii check) (liii pi code core extension-notify))

(check-set-mode! 'report-failed)

;; 未 arm：返回 #f
(pi-extension-notify-reset!)
(check (pi-extension-notify "hi") => #f)
;; 已 arm：返回回调结果
(pi-extension-notify-set! (lambda (msg) (string-append "got:" msg)))
(check (pi-extension-notify "hi") => "got:hi")
;; 透传任意值
(pi-extension-notify-set! (lambda (msg) msg))
(check (pi-extension-notify 42) => 42)
(pi-extension-notify-reset!)

(check-report)
