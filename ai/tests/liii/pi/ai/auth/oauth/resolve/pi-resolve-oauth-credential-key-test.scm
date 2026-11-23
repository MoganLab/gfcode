;; pi-resolve-oauth-credential-key
;; oauth 凭据解析：未过期（60s 缓冲）直接返回 access，过期透明刷新并落盘。
;;
;; 语法
;; ----
;; (pi-resolve-oauth-credential-key cred opt-env save! remove!) -> string? 或 #f
;;
;; 参数
;; ----
;; cred : pi-credential?
;; oauth 凭据。
;;
;; opt-env : list?
;; 自定义环境变量表（KIMI_CODE_OAUTH_HOST 覆盖）。
;;
;; save! : procedure?
;; 刷新成功后的落盘回调 (lambda (new-cred) ...)。
;;
;; remove! : procedure?
;; 401/403/invalid_grant 时的清除回调 (lambda (provider) ...)。
;;
;; 返回值
;; ----
;; string? 或 #f
;; 生效 access token；刷新失败返回 #f（unauthorized 时已调 remove!）。

(import (scheme base)
  (liii check)
  (liii string)
  (liii subprocess)
  (liii pi ai time)
  (liii pi ai config credential)
  (liii pi ai auth oauth resolve)
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

;; 1. 未过期：直接返回 access，不触发回调
(let* ((cred (pi-credential "kimi-coding"
               #f
               "oauth"
               "fresh-acc"
               "ref"
               (+ (pi-current-time-millis) 3600000)
               #f
             ) ;pi-credential
       ) ;cred
       (saved '())
       (removed '())
      ) ;
  (check
    (pi-resolve-oauth-credential-key cred
      '()
      (lambda (c) (set! saved (cons c saved)))
      (lambda (p) (set! removed (cons p removed)))
    ) ;pi-resolve-oauth-credential-key
    =>
    "fresh-acc"
  ) ;check
  (check saved => '())
  (check removed => '())
) ;let*

;; 2. 60s 缓冲内视为过期：走刷新
(let* ((proc (process-spawn (list "python3" stub-file "refresh-ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (cred (pi-credential "kimi-coding"
               #f
               "oauth"
               "old-acc"
               "stub-refresh-token"
               (+ (pi-current-time-millis) 30000)
               host
             ) ;pi-credential
       ) ;cred
       (saved '())
       (removed '())
      ) ;
  (check
    (pi-resolve-oauth-credential-key cred
      '()
      (lambda (c) (set! saved (cons c saved)))
      (lambda (p) (set! removed (cons p removed)))
    ) ;pi-resolve-oauth-credential-key
    =>
    "stub-access-token-2"
  ) ;check
  (check (length saved) => 1)
  (check (pi-credential-refresh (car saved)) => "stub-refresh-token-2")
  (check removed => '())
  (process-kill proc)
) ;let*

;; 3. 已过期 + 401 invalid_grant：remove! 被调用，返回 #f
(let* ((proc (process-spawn (list "python3" stub-file "refresh-401") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (cred (pi-credential "kimi-coding"
               #f
               "oauth"
               "old-acc"
               "stub-refresh-token"
               (- (pi-current-time-millis) 1000)
               host
             ) ;pi-credential
       ) ;cred
       (saved '())
       (removed '())
      ) ;
  (check
    (pi-resolve-oauth-credential-key cred
      '()
      (lambda (c) (set! saved (cons c saved)))
      (lambda (p) (set! removed (cons p removed)))
    ) ;pi-resolve-oauth-credential-key
    =>
    #f
  ) ;check
  (check saved => '())
  (check removed => '("kimi-coding"))
  (process-kill proc)
) ;let*

;; 4. 网络不可达（region 指向死端口）：保留凭据（不 remove），返回 #f
(let* ((cred (pi-credential "kimi-coding"
               #f
               "oauth"
               "old-acc"
               "ref"
               (- (pi-current-time-millis) 1000)
               "http://127.0.0.1:1"
             ) ;pi-credential
       ) ;cred
       (removed '())
      ) ;
  (check
    (pi-resolve-oauth-credential-key cred
      '()
      (lambda (c) #f)
      (lambda (p) (set! removed (cons p removed)))
    ) ;pi-resolve-oauth-credential-key
    =>
    #f
  ) ;check
  (check removed => '())
) ;let*

(check-report)
