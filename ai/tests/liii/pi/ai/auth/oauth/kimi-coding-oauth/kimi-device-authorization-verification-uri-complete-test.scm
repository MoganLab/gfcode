;; kimi-device-authorization-verification-uri-complete
;; 读取设备授权记录的 verification_uri_complete（带 user_code 的验证页）。
;;
;; 语法
;; ----
;; (kimi-device-authorization-verification-uri-complete device) -> string?
;;
;; 参数
;; ----
;; device : kimi-device-authorization?
;; kimi-device-authorize 返回的记录。
;;
;; 返回值
;; ----
;; string?
;; 浏览器直接打开即可完成授权的 URL。

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
  (check (kimi-device-authorization-verification-uri-complete (kimi-device-authorize host)
         ) ;kimi-device-authorization-verification-uri-complete
    =>
    "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234"
  ) ;check
  (process-kill proc)
) ;let*

(check-report)
