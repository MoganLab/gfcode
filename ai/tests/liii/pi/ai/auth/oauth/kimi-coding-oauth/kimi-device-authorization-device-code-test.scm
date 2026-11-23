;; kimi-device-authorization-device-code
;; 读取设备授权记录的 device_code。
;;
;; 语法
;; ----
;; (kimi-device-authorization-device-code device) -> string?
;;
;; 参数
;; ----
;; device : kimi-device-authorization?
;; kimi-device-authorize 返回的记录。
;;
;; 返回值
;; ----
;; string?
;; 轮询 token 端点用的设备码。

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
  (check (kimi-device-authorization-device-code (kimi-device-authorize host))
    =>
    "stub-device-code"
  ) ;check
  (process-kill proc)
) ;let*

(check-report)
