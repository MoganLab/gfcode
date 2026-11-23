;; kimi-oauth-login
;; 完整设备码登录：设备授权 → notify device_code 事件 → 轮询换 token。
;;
;; 语法
;; ----
;; (kimi-oauth-login)
;; (kimi-oauth-login notify cancelled? provider opt-env)
;;
;; 参数
;; ----
;; notify : procedure? 或 #f
;; 接收 (device_code user-code uri interval expires) 事件的回调。
;;
;; cancelled? : procedure? 或 #f
;; 取消谓词。
;;
;; provider : string?
;; 凭据归属服务商，默认 "kimi-coding"。
;;
;; opt-env : list?
;; 自定义环境变量表（KIMI_CODE_OAUTH_HOST 覆盖 host）。
;;
;; 返回值
;; ----
;; pi-credential?
;; type=oauth 凭据；env 覆盖 host 时 region 记录覆盖值，默认 host 不写。

(import (scheme base)
  (liii check)
  (liii string)
  (liii subprocess)
  (liii pi ai config credential)
  (liii pi ai auth oauth kimi-coding-oauth)
) ;import

(check-set-mode! 'report-failed)

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define stub-file
  (if (file-exists? "tests/stub_kimi_oauth_server.py")
    "tests/stub_kimi_oauth_server.py"
    "ai/tests/stub_kimi_oauth_server.py"
  ) ;if
) ;define

(let* ((proc (process-spawn (list "python3" stub-file "ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (events '())
      ) ;
  ;; 1. notify 收到 device_code 事件；凭据带 region（env 覆盖了 host）
  (let ((cred
          (kimi-oauth-login (lambda (ev) (set! events (cons ev events)))
            #f
            "kimi-coding"
            (list (cons "KIMI_CODE_OAUTH_HOST" host))
          ) ;kimi-oauth-login
        ) ;cred
       ) ;
    (check (length events) => 1)
    (let ((ev (car events)))
      (check (car ev) => 'device_code)
      (check (cadr ev) => "ABCD-1234")
      (check (caddr ev)
        =>
        "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234"
      ) ;check
      (check (cadddr ev) => 1)
      (check (car (cddddr ev)) => 900)
    ) ;let
    (check-true (pi-credential-oauth? cred))
    (check (pi-credential-access cred) => "stub-access-token")
    (check (pi-credential-region cred) => host)
  ) ;let

  ;; 2. 取消谓词已置位：kimi-oauth-cancelled
  (check-catch 'kimi-oauth-cancelled
    (kimi-oauth-login #f
      (lambda () #t)
      "kimi-coding"
      (list (cons "KIMI_CODE_OAUTH_HOST" host))
    ) ;kimi-oauth-login
  ) ;check-catch

  (process-kill proc)
) ;let*

(check-report)
