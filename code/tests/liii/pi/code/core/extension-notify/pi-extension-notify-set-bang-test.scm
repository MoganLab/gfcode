;; pi-extension-notify-set!
;; 设置扩展通知回调；#f 表示未 arm（回退 stderr）。
;;
;; 语法
;; ----
;; (pi-extension-notify-set! fn)
;;
;; 参数
;; ----
;; fn : procedure or #f
;; 通知回调过程；传入 #f 等价于重置。
;;
;; 返回值
;; ----
;; unspecified

(import (scheme base) (liii check) (liii pi code core extension-notify))

(check-set-mode! 'report-failed)

(pi-extension-notify-reset!)
(pi-extension-notify-set! (lambda (msg) #t))
(check-true (pi-extension-notify?))
(pi-extension-notify-set! #f)
(check-false (pi-extension-notify?))
;; 非过程参数安全回退为 #f
(pi-extension-notify-set! 'not-a-proc)
(check-false (pi-extension-notify?))

(check-report)
