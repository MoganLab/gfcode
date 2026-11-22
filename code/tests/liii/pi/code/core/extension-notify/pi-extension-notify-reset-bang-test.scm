;; pi-extension-notify-reset!
;; 重置扩展通知回调为 #f（未 arm 状态）。
;;
;; 语法
;; ----
;; (pi-extension-notify-reset!)
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; unspecified

(import (scheme base) (liii check) (liii pi code core extension-notify))

(check-set-mode! 'report-failed)

(pi-extension-notify-set! (lambda (msg) #t))
(check-true (pi-extension-notify?))
(pi-extension-notify-reset!)
(check-false (pi-extension-notify?))
;; 重复重置保持未 arm
(pi-extension-notify-reset!)
(check-false (pi-extension-notify?))

(check-report)
