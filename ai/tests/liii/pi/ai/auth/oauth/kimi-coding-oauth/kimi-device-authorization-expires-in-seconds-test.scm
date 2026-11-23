;; kimi-device-authorization-expires-in-seconds
;; 读取设备授权记录的有效期秒数。
;;
;; 语法
;; ----
;; (kimi-device-authorization-expires-in-seconds device) -> number?
;;
;; 参数
;; ----
;; device : kimi-device-authorization?
;; kimi-device-authorize 返回的记录。
;;
;; 返回值
;; ----
;; number?
;; 服务端 expires_in；缺失/非法时回退 900（15 分钟，对齐 pi）。

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
  (check (kimi-device-authorization-expires-in-seconds (kimi-device-authorize host))
    =>
    900
  ) ;check
  (process-kill proc)
) ;let*

(check-report)
