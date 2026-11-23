;; kimi-poll-token
;; 设备码轮询换取 token：POST {host}/api/oauth/token（device_code grant）。
;;
;; 语法
;; ----
;; (kimi-poll-token host device provider region)
;; (kimi-poll-token host device provider region cancelled?)
;;
;; 参数
;; ----
;; host : string?
;; OAuth host。
;;
;; device : kimi-device-authorization?
;; kimi-device-authorize 返回的设备授权记录。
;;
;; provider : string?
;; 凭据归属的服务商 id。
;;
;; region : string? 或 #f
;; 登录时的 host 覆盖值（写入凭据 region 字段）。
;;
;; cancelled? : procedure? 或 #f
;; 取消谓词。
;;
;; 返回值
;; ----
;; pi-credential?
;; type=oauth 的凭据（access/refresh/expires）；失败/拒绝/超时抛
;; kimi-oauth-error，取消抛 kimi-oauth-cancelled。

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

(define (with-stub scenario body)
  (let* ((proc (process-spawn (list "python3" stub-file scenario) :stdout 'pipe))
         (port (parse-port-line (process-read-line proc)))
         (host (string-append "http://127.0.0.1:" (number->string port)))
        ) ;
    (let ((result (body host)))
      (process-kill proc)
      result
    ) ;let
  ) ;let*
) ;define

;; 1. pending 一次后 complete：得到 oauth 凭据
(with-stub "ok"
  (lambda (host)
    (let* ((device (kimi-device-authorize host))
           (cred (kimi-poll-token host device "kimi-coding" #f))
          ) ;
      (check-true (pi-credential-oauth? cred))
      (check (pi-credential-provider cred) => "kimi-coding")
      (check (pi-credential-access cred) => "stub-access-token")
      (check (pi-credential-refresh cred) => "stub-refresh-token")
      (check-true (> (pi-credential-expires cred) 0))
      (check (pi-credential-region cred) => #f)
    ) ;let*
  ) ;lambda
) ;with-stub

;; 2. region 透传到凭据
(with-stub "ok"
  (lambda (host)
    (let* ((device (kimi-device-authorize host))
           (cred (kimi-poll-token host device "kimi-coding" host))
          ) ;
      (check (pi-credential-region cred) => host)
    ) ;let*
  ) ;lambda
) ;with-stub

;; 3. slow_down 后 complete
(with-stub "slow-down"
  (lambda (host)
    (let* ((device (kimi-device-authorize host))
           (cred (kimi-poll-token host device "kimi-coding" #f))
          ) ;
      (check (pi-credential-access cred) => "stub-access-token")
    ) ;let*
  ) ;lambda
) ;with-stub

;; 4. access_denied / expired_token / 500：kimi-oauth-error
(with-stub "denied"
  (lambda (host)
    (check-catch 'kimi-oauth-error
      (kimi-poll-token host (kimi-device-authorize host) "kimi-coding" #f)
    ) ;check-catch
  ) ;lambda
) ;with-stub
(with-stub "expired"
  (lambda (host)
    (check-catch 'kimi-oauth-error
      (kimi-poll-token host (kimi-device-authorize host) "kimi-coding" #f)
    ) ;check-catch
  ) ;lambda
) ;with-stub
(with-stub "poll-500"
  (lambda (host)
    (check-catch 'kimi-oauth-error
      (kimi-poll-token host (kimi-device-authorize host) "kimi-coding" #f)
    ) ;check-catch
  ) ;lambda
) ;with-stub

;; 5. 取消谓词：kimi-oauth-cancelled
(with-stub "ok"
  (lambda (host)
    (check-catch 'kimi-oauth-cancelled
      (kimi-poll-token host
        (kimi-device-authorize host)
        "kimi-coding"
        #f
        (lambda () #t)
      ) ;kimi-poll-token
    ) ;check-catch
  ) ;lambda
) ;with-stub

(check-report)
