;; login-device-code-user-code
;; 读取组件展示的用户码。
;;
;; 语法
;; ----
;; (login-device-code-user-code comp) -> string?
;;
;; 参数
;; ----
;; comp : login-device-code?
;; device-code 组件。
;;
;; 返回值
;; ----
;; string?
;; 构造时传入的 user_code。

(import (liii check) (liii pi app interactive login-device-code))

(check-set-mode! 'report-failed)

(check (login-device-code-user-code (make-login-device-code "kimi-coding"
                                      "WXYZ-5678"
                                      "https://x.example"
                                      (lambda () #f)
                                    ) ;make-login-device-code
       ) ;login-device-code-user-code
  =>
  "WXYZ-5678"
) ;check

(check-report)
