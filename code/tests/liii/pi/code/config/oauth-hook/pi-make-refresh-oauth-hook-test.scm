;; pi-make-refresh-oauth-hook
;; 401 强制刷新更新内存 store，并把轮换后的 refresh/expires 落盘 auth.json
;; （access token 短命，仅保留内存；盘上 access 保持登录时的旧值）。
;; 后续 request-oauth-key 即使使用配置副本，也读取最新 access token。
;; invalid_grant 时同时清除内存 store 与 auth.json 条目。

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii string)
  (liii subprocess)
  (liii pi ai config runtime)
  (liii pi ai config credential)
  (liii pi ai auth)
  (liii pi ai keyring)
  (liii pi ai time)
  (liii pi ai auth oauth store)
  (liii pi code config oauth-hook)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-make-refresh-oauth-hook-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(define stub-file
  (cond ((file-exists? "code/tests/stub_kimi_oauth_server.py")
         "code/tests/stub_kimi_oauth_server.py"
        ) ;
        ((file-exists? "tests/stub_kimi_oauth_server.py")
         "tests/stub_kimi_oauth_server.py"
        ) ;
        (else "../code/tests/stub_kimi_oauth_server.py")
  ) ;cond
) ;define

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define (write-auth! host refresh-token)
  (path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
    (string-append "{\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"old-acc\","
      "\"refresh\":\""
      refresh-token
      "\",\"expires\":"
      (number->string (+ (pi-current-time-millis) 3600000))
      ",\"region\":\""
      host
      "\"}}"
    ) ;string-append
  ) ;path-write-text
) ;define

(define (stored-credential)
  (car (pi-load-auth TMP-DIR))
) ;define

;; 刷新成功：401 重试取得新 token，配置副本从同一 store 取得新 token。
(let* ((proc (process-spawn (list "python3" stub-file "refresh-ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (write-auth! host "stub-refresh-token")
  (let* ((cfg (pi-sync-oauth-refresh-hook (make-pi-config :config-dir TMP-DIR :provider "kimi-coding" :api-key "old-acc")
                '()
              ) ;pi-sync-oauth-refresh-hook
         ) ;cfg
         (copy (pi-cfg-set cfg 'thinking-level "high"))
         (next ((pi-cfg-ref cfg 'refresh-oauth-key) cfg "old-acc"))
        ) ;
    (check next => "stub-access-token-2")
    (check (pi-request-api-key copy) => "stub-access-token-2")
    (check (pi-cfg-ref cfg 'api-key) => "old-acc")
    (check (pi-cfg-ref copy 'api-key) => "old-acc")
    ;; 刷新后 access 仅内存，盘上 access 仍为旧值；轮换后的 refresh token 落盘。
    (check (pi-credential-access (stored-credential)) => "old-acc")
    (check (pi-credential-refresh (stored-credential)) => "stub-refresh-token-2")
    ;; 后续读取不再触发刷新；再次强刷会使用轮换后的 refresh token。
    (check (pi-request-api-key cfg) => "stub-access-token-2")
  ) ;let*
  (process-kill proc)
) ;let*

;; 过期 token 在请求前刷新，而不是在配置解析时刷新。
(let* ((proc (process-spawn (list "python3" stub-file "refresh-ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (write-auth! host "stub-refresh-token")
  (let* ((cfg (pi-sync-oauth-refresh-hook (make-pi-config :config-dir TMP-DIR :provider "kimi-coding" :api-key "old-acc")
                '()
              ) ;pi-sync-oauth-refresh-hook
         ) ;cfg
        ) ;
    (check (pi-request-api-key cfg) => "old-acc")
    (check (pi-credential-access (stored-credential)) => "old-acc")
    ;; 上述快照未过期；用 store 的公开写入接口替换为过期凭据。
    ((lambda (store)
       (pi-oauth-store-clear! store)
       (pi-oauth-store-load! store
         (list (pi-credential "kimi-coding"
                 #f
                 "oauth"
                 "expired-acc"
                 "stub-refresh-token"
                 (- (pi-current-time-millis) 1000)
                 host
               ) ;pi-credential
         ) ;list
       ) ;pi-oauth-store-load!
     ) ;lambda
     (pi-cfg-ref cfg 'oauth-store)
    ) ;
    (check (pi-request-api-key cfg) => "stub-access-token-2")
    (check (pi-credential-access (stored-credential)) => "old-acc")
    ;; 过期刷新同样把轮换后的 refresh token 落盘。
    (check (pi-credential-refresh (stored-credential)) => "stub-refresh-token-2")
  ) ;let*
  (process-kill proc)
) ;let*

;; 刷新 unauthorized：清内存与 auth.json 条目，返回 #f。
(let* ((proc (process-spawn (list "python3" stub-file "refresh-401") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (write-auth! host "stub-refresh-token")
  (let* ((cfg (pi-sync-oauth-refresh-hook (make-pi-config :config-dir TMP-DIR :provider "kimi-coding")
                '()
              ) ;pi-sync-oauth-refresh-hook
         ) ;cfg
         (next ((pi-cfg-ref cfg 'refresh-oauth-key) cfg "old-acc"))
        ) ;
    (check next => #f)
    (check (pi-request-api-key cfg) => #f)
    (check (length (pi-load-auth TMP-DIR)) => 0)
  ) ;let*
  (process-kill proc)
) ;let*

;; provider 无 oauth 凭据：不影响其他 provider。
(path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
  "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"}}"
) ;path-write-text
(let ((cfg (pi-sync-oauth-refresh-hook (make-pi-config :config-dir TMP-DIR :provider "kimi-coding")
             '()
           ) ;pi-sync-oauth-refresh-hook
      ) ;cfg
     ) ;
  (check (pi-cfg-ref cfg 'refresh-oauth-key) => #f)
  (check (length (pi-load-auth TMP-DIR)) => 1)
) ;let

(rmtree TMP-DIR)
(check-report)
