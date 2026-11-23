;; kimi-device-authorize
;; 发起 RFC 8628 设备授权：POST {host}/api/oauth/device_authorization。
;;
;; 语法
;; ----
;; (kimi-device-authorize host) -> kimi-device-authorization?
;;
;; 参数
;; ----
;; host : string?
;; OAuth host（如 https://auth.kimi.com 或本地 stub）。
;;
;; 返回值
;; ----
;; kimi-device-authorization?
;; 含 device-code/user-code/verification-uri(-complete)/interval/expires 的记录。
;; 非 2xx 或字段缺失抛 kimi-oauth-error。

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

(define (find-stub)
  (let loop
    ((candidates '("tests/stub_kimi_oauth_server.py"
                   "ai/tests/stub_kimi_oauth_server.py"
                   "stub_kimi_oauth_server.py")
     ) ;candidates
    ) ;
    (cond ((null? candidates)
           (error 'file-not-found "stub_kimi_oauth_server.py not found")
          ) ;
          ((file-exists? (car candidates)) (car candidates))
          (else (loop (cdr candidates)))
    ) ;cond
  ) ;let
) ;define

;; 正常设备授权（本地 stub）
(let* ((proc (process-spawn (list "python3" (find-stub) "ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (check-true (number? port))
  (let ((device (kimi-device-authorize host)))
    (check-true (kimi-device-authorization? device))
    (check (kimi-device-authorization-device-code device) => "stub-device-code")
    (check (kimi-device-authorization-user-code device) => "ABCD-1234")
    (check (kimi-device-authorization-verification-uri device)
      =>
      "https://www.kimi.com/code"
    ) ;check
    (check (kimi-device-authorization-verification-uri-complete device)
      =>
      "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234"
    ) ;check
    (check (kimi-device-authorization-interval-seconds device) => 1)
    (check (kimi-device-authorization-expires-in-seconds device) => 900)
  ) ;let
  (process-kill proc)
) ;let*

;; 500：抛 kimi-oauth-error
(let* ((proc (process-spawn (list "python3" (find-stub) "authorize-500") :stdout 'pipe)
       ) ;proc
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (check-catch 'kimi-oauth-error (kimi-device-authorize host))
  (process-kill proc)
) ;let*

;; 200 但字段缺失：抛 kimi-oauth-error
(let* ((proc (process-spawn (list "python3" (find-stub) "authorize-bad") :stdout 'pipe)
       ) ;proc
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (check-catch 'kimi-oauth-error (kimi-device-authorize host))
  (process-kill proc)
) ;let*

;; 网络不可达：status 0 归一为 kimi-oauth-error
(check-catch 'kimi-oauth-error (kimi-device-authorize "http://127.0.0.1:1"))

(check-report)
