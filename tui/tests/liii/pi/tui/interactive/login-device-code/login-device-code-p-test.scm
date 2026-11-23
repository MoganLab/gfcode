;; login-device-code?
;; 判断组件是否为 login-device-code。
;;
;; 语法
;; ----
;; (login-device-code? obj) -> boolean?
;;
;; 参数
;; ----
;; obj : any
;; 任意对象。
;;
;; 返回值
;; ----
;; boolean?
;; make-login-device-code 构造的组件为 #t。

(import (liii check)
  (liii tui)
  (liii tui component)
  (liii pi tui interactive login-device-code)
  (liii pi tui interactive login-dialog)
) ;import

(check-set-mode! 'report-failed)

(check-true (login-device-code? (make-login-device-code "kimi-coding"
                                  "ABCD-1234"
                                  "https://x.example"
                                  (lambda () #f)
                                ) ;make-login-device-code
            ) ;login-device-code?
) ;check-true
(check-false
  (login-device-code? (make-login-dialog "kimi-coding" (lambda (k) #f) (lambda () #f))
  ) ;login-device-code?
) ;check-false
(check-false (login-device-code? "x"))
(check-false (login-device-code? #f))

(check-report)
