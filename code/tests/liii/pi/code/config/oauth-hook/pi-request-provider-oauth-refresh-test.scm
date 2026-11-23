;; OAuth 凭据保存在独立的内存 store 中。
;; 第一次请求旧 token 收到 401，刷新后成功；第二次即使使用新的配置副本，
;; 也从共享 store 读取新 token，不再次刷新，不修改配置或 auth.json。
;;
;; 语法
;; ----
;; (pi-sync-oauth-refresh-hook cfg . opt-env)
;; (pi-request cfg ...) 经由 request-oauth-key / refresh-oauth-key 钩子取 key
;;
;; 参数
;; ----
;; cfg : pi-config?
;; 含 provider 与 config-dir 的请求配置。
;;
;; opt-env : list?
;; 可选 (env-alist)，缺省取当前进程环境变量。
;;
;; 返回值
;; ----
;; pi-config?
;; 注入共享 oauth-store 与钩子后的配置；401 刷新后新 token 生效，
;; 轮换的 refresh token 落盘、access 仅内存。

(import (scheme base)
  (scheme file)
  (scheme process-context)
  (liii check)
  (liii path)
  (liii shutil)
  (liii string)
  (liii subprocess)
  (liii pi ai config model-metadata)
  (liii pi ai config runtime)
  (liii pi ai message)
  (liii pi ai dispatch)
  (liii pi ai time)
  (liii pi code config oauth-hook)
  (liii pi ai auth)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-request-provider-oauth-refresh-test")
  ) ;path->string
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(define stub-file
  (if (file-exists? "tests/stub_oauth_refresh_request_server.py")
    "tests/stub_oauth_refresh_request_server.py"
    "code/tests/stub_oauth_refresh_request_server.py"
  ) ;if
) ;define

(define oauth-stub-file
  (if (file-exists? "tests/stub_kimi_oauth_server.py")
    "tests/stub_kimi_oauth_server.py"
    "code/tests/stub_kimi_oauth_server.py"
  ) ;if
) ;define

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define (response-text resp)
  (pi-text-block-text (car (pi-assistant-message-content resp)))
) ;define

(define (request cfg text)
  (pi-request-provider "kimi-coding" cfg (list (pi-user-message text)) #f '() 10)
) ;define

(let* ((proc (process-spawn (list "python3" stub-file) :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (base-url (string-append "http://127.0.0.1:" (number->string port)))
       (oauth-proc (process-spawn (list "python3" oauth-stub-file "refresh-ok") :stdout 'pipe)
       ) ;oauth-proc
       (oauth-port (parse-port-line (process-read-line oauth-proc)))
       (oauth-host (string-append "http://127.0.0.1:" (number->string oauth-port)))
       (auth-file (path->string (path-join (path TMP-DIR) (path "auth.json"))))
      ) ;
  (path-write-text auth-file
    (string-append "{\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"old-access\","
      "\"refresh\":\"stub-refresh-token\",\"expires\":"
      (number->string (+ (pi-current-time-millis) 3600000))
      ",\"region\":\""
      oauth-host
      "\"}}"
    ) ;string-append
  ) ;path-write-text
  (let ((cfg
          (pi-sync-oauth-refresh-hook
            (make-pi-config
              :config-dir   TMP-DIR
              :provider     "kimi-coding"
              :provider-api "openai-completions"
              :model-id     "kimi-for-coding"
              :model-meta
              (pi-model-metadata "kimi-for-coding" "Kimi" "kimi-coding" base-url 4096 128)
              :api-key  "old-access"
              :settings '((retry (enabled . #f)))
              :extras   (list (cons 'headers '()))
            ) ;make-pi-config
            ;; 使用真实进程环境变量，覆盖首个 pair 被误当成完整 env-alist 的回归。
            (get-environment-variables)
          ) ;pi-sync-oauth-refresh-hook
        ) ;cfg
       ) ;
    (let ((first (request cfg "first")))
      (when (not (equal? (pi-assistant-message-stop-reason first) "stop"))
        (display (pi-assistant-message-error-message first))
        (newline)
      ) ;when
      (check (pi-assistant-message-stop-reason first) => "stop")
      (check (response-text first) => "PlainOK:stub-access-token-2")
      (check (pi-cfg-ref cfg 'api-key) => "old-access")
    ) ;let
    ;; 同时改变多个字段，强制走 dispatch 的补齐\/复制路径。
    ;; 注意：不能覆盖 model-meta，否则 base-url 会回退到 provider 默认值，
    ;; 导致请求发往真实 API 而非 stub 服务器。
    (let* ((copy (pi-cfg-merge cfg '((tools . #f) (settings . #f))))
           (second (request copy "second"))
          ) ;
      (check (pi-assistant-message-stop-reason second) => "stop")
      (check (response-text second) => "PlainOK:stub-access-token-2")
      (check (pi-cfg-ref copy 'api-key) => "old-access")
    ) ;let*
    ;; 刷新后 access 仅内存，盘上 access 仍为旧值；轮换后的 refresh token 落盘。
    (check-true (string-contains? (path-read-text auth-file) "old-access"))
    (check-true (string-contains? (path-read-text auth-file) "stub-refresh-token-2")
    ) ;check-true
    (check-false (string-contains? (path-read-text auth-file) "stub-access-token-2")
    ) ;check-false
  ) ;let
  (process-kill oauth-proc)
  (process-kill proc)
) ;let*

(rmtree TMP-DIR)

(check-report)
