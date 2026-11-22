;; pi-extension-notify?
;; 判定是否已 arm 通知回调。
;;
;; 语法
;; ----
;; (pi-extension-notify?)
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; boolean
;; 已 arm 过程回调时返回 #t，否则返回 #f。

(import (scheme base) (liii check) (liii pi code core extension-notify))

(check-set-mode! 'report-failed)

(pi-extension-notify-reset!)
(check-false (pi-extension-notify?))
(pi-extension-notify-set! (lambda (msg) #t))
(check-true (pi-extension-notify?))
(pi-extension-notify-reset!)
(check-false (pi-extension-notify?))

(check-report)
