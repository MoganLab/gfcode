;; kimi-device-authorization?
;; 判断对象是否为设备授权响应记录。
;;
;; 语法
;; ----
;; (kimi-device-authorization? obj) -> boolean?
;;
;; 参数
;; ----
;; obj : any
;; 任意对象。
;;
;; 返回值
;; ----
;; boolean?
;; kimi-device-authorize 返回的记录为 #t，其余 #f。

(import (scheme base)
  (liii check)
  (liii string)
  (liii subprocess)
  (liii pi ai auth oauth kimi-coding-oauth)
) ;import

(check-set-mode! 'report-failed)

(check-false (kimi-device-authorization? "device"))
(check-false (kimi-device-authorization? #f))
(check-false (kimi-device-authorization? '(device_code . "x")))

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
  (check-true (kimi-device-authorization? (kimi-device-authorize host)))
  (process-kill proc)
) ;let*

(check-report)
