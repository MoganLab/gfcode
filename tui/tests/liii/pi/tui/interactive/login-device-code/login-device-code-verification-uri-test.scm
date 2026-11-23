;; login-device-code-verification-uri
;; 读取组件展示的验证 URL（verification_uri_complete）。
;;
;; 语法
;; ----
;; (login-device-code-verification-uri comp) -> string?
;;
;; 参数
;; ----
;; comp : login-device-code?
;; device-code 组件。
;;
;; 返回值
;; ----
;; string?
;; 构造时传入的验证 URL。

(import (liii check) (liii pi tui interactive login-device-code))

(check-set-mode! 'report-failed)

(check (login-device-code-verification-uri (make-login-device-code "kimi-coding"
                                             "A"
                                             "https://www.kimi.com/code/authorize_device?user_code=A"
                                             (lambda () #f)
                                           ) ;make-login-device-code
       ) ;login-device-code-verification-uri
  =>
  "https://www.kimi.com/code/authorize_device?user_code=A"
) ;check

(check-report)
