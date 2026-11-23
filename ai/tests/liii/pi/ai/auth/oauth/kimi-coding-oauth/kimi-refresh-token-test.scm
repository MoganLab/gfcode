;; kimi-refresh-token
;; refresh_token 刷新：429/5xx/网络错误退避重试 3 次，401/403/invalid_grant
;; 抛 kimi-oauth-unauthorized。
;;
;; 语法
;; ----
;; (kimi-refresh-token host refresh-token provider region) -> pi-credential?
;;
;; 参数
;; ----
;; host : string?
;; OAuth host。
;;
;; refresh-token : string?
;; 已存的 refresh token。
;;
;; provider : string?
;; 凭据归属服务商。
;;
;; region : string? 或 #f
;; 透传到新凭据的 region。
;;
;; 返回值
;; ----
;; pi-credential?
;; 新 oauth 凭据；401/403/invalid_grant 抛 kimi-oauth-unauthorized，
;; 其余失败抛 kimi-oauth-error。

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

;; 1. 正常刷新：新 access/refresh/expires，region 透传
(with-stub "refresh-ok"
  (lambda (host)
    (let ((cred (kimi-refresh-token host "stub-refresh-token" "kimi-coding" host)))
      (check-true (pi-credential-oauth? cred))
      (check (pi-credential-access cred) => "stub-access-token-2")
      (check (pi-credential-refresh cred) => "stub-refresh-token-2")
      (check-true (> (pi-credential-expires cred) 0))
      (check (pi-credential-region cred) => host)
    ) ;let
  ) ;lambda
) ;with-stub

;; 2. 401 invalid_grant：kimi-oauth-unauthorized
(with-stub "refresh-401"
  (lambda (host)
    (check-catch 'kimi-oauth-unauthorized
      (kimi-refresh-token host "stub-refresh-token" "kimi-coding" #f)
    ) ;check-catch
  ) ;lambda
) ;with-stub

;; 3. 403：kimi-oauth-unauthorized
(with-stub "refresh-403"
  (lambda (host)
    (check-catch 'kimi-oauth-unauthorized
      (kimi-refresh-token host "stub-refresh-token" "kimi-coding" #f)
    ) ;check-catch
  ) ;lambda
) ;with-stub

;; 4. 429 两次后 200：退避重试成功（1s+2s 退避）
(with-stub "refresh-flaky"
  (lambda (host)
    (let ((cred (kimi-refresh-token host "stub-refresh-token" "kimi-coding" #f)))
      (check (pi-credential-access cred) => "stub-access-token-2")
    ) ;let
  ) ;lambda
) ;with-stub

;; 5. 持续 500：重试用尽后 kimi-oauth-error（1+2+4s 退避）
(with-stub "refresh-500"
  (lambda (host)
    (check-catch 'kimi-oauth-error
      (kimi-refresh-token host "stub-refresh-token" "kimi-coding" #f)
    ) ;check-catch
  ) ;lambda
) ;with-stub

(check-report)
