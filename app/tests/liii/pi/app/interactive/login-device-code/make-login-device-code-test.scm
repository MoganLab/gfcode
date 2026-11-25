;; make-login-device-code
;; 构造 device-code 展示组件：user_code + verification URL + 轮询态。
;;
;; 语法
;; ----
;; (make-login-device-code provider user-code verification-uri on-cancel)
;;
;; 参数
;; ----
;; provider : string?
;; 服务商 id。
;;
;; user-code : string?
;; 用户码（形如 ABCD-1234）。
;;
;; verification-uri : string?
;; 带 user_code 的验证 URL。
;;
;; on-cancel : procedure?
;; Esc 取消回调。
;;
;; 返回值
;; ----
;; component?
;; login-device-code 组件；渲染含 user_code 与 URL。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii tui)
  (liii tui component)
  (liii pi app interactive login-device-code)
) ;import

(check-set-mode! 'report-failed)

(let ((comp (make-login-device-code "kimi-coding"
              "ABCD-1234"
              "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234"
              (lambda () #f)
            ) ;make-login-device-code
      ) ;comp
     ) ;
  (check-true (component? comp))
  (check-true (login-device-code? comp))
  (let ((lines (component-render comp 80)))
    (check-true (any (lambda (l) (string-contains? l "ABCD-1234")) lines))
    (check-true (any (lambda (l) (string-contains? l "authorize_device?user_code=ABCD-1234"))
                  lines
                ) ;any
    ) ;check-true
    (check-true (any (lambda (l) (string-contains? l "Waiting")) lines))
    (check-true (any (lambda (l) (string-contains? l "kimi-coding")) lines))
  ) ;let
) ;let

(check-report)
