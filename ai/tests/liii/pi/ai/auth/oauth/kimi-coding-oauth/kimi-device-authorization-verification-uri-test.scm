;; kimi-device-authorization-verification-uri
;; 读取设备授权记录的 verification_uri（不含 user_code 的验证页）。
;;
;; 语法
;; ----
;; (kimi-device-authorization-verification-uri device) -> string?
;;
;; 参数
;; ----
;; device : kimi-device-authorization?
;; kimi-device-authorize 返回的记录。
;;
;; 返回值
;; ----
;; string?
;; 已通过 http/https 白名单校验的验证 URL。

(import (scheme base)
  (liii check)
  (liii string)
  (liii subprocess)
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
      ) ;
  (check (kimi-device-authorization-verification-uri (kimi-device-authorize host))
    =>
    "https://www.kimi.com/code"
  ) ;check
  (process-kill proc)
) ;let*

(check-report)
