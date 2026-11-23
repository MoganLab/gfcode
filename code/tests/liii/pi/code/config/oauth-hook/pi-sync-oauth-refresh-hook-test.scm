;; pi-sync-oauth-refresh-hook
;; 按 cfg 当前 provider 同步 refresh-oauth-key 钩子：有 oauth 凭据注入，
;; 无则移除残留钩子。切模（含同 provider）与 /login 后 reload 都依赖此函数。
;;
;; 语法
;; ----
;; (pi-sync-oauth-refresh-hook cfg . opt-env) -> cfg
;;
;; 参数
;; ----
;; cfg : pi-config? 或 alist
;; 含 provider 与 config-dir（或 agent-dir）的配置。
;;
;; opt-env : list?
;; 可选 (env-alist)，缺省取当前进程环境变量。
;;
;; 返回值
;; ----
;; cfg
;; 同类型配置：refresh-oauth-key 为过程（有 oauth 凭据）或 #f（无）。

(import (scheme base)
  (scheme file)
  (scheme process-context)
  (liii check)
  (liii path)
  (liii shutil)
  (liii pi ai config runtime)
  (liii pi ai keyring)
  (liii pi ai time)
  (liii pi code config oauth-hook)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-sync-oauth-refresh-hook-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(define (write-auth! text)
  (path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json"))) text)
) ;define

(define (oauth-json expires)
  (string-append "{\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"old-acc\","
    "\"refresh\":\"stub-refresh-token\",\"expires\":"
    (number->string expires)
    "}}"
  ) ;string-append
) ;define

(define (make-cfg provider)
  (make-pi-config :config-dir TMP-DIR :provider provider)
) ;define

;; 1. provider 有 oauth 凭据：注入钩子（pi-oauth-refresh-enabled? 为真）
(write-auth! (oauth-json (+ (pi-current-time-millis) 3600000)))
(let ((cfg (pi-sync-oauth-refresh-hook (make-cfg "kimi-coding") '())))
  (check-true (pi-oauth-refresh-enabled? cfg))
) ;let

;; 2. provider 无 oauth 凭据（api_key）：不注入
(write-auth! "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"}}")
(let ((cfg (pi-sync-oauth-refresh-hook (make-cfg "google") '())))
  (check-false (pi-oauth-refresh-enabled? cfg))
  (check (pi-cfg-ref cfg 'refresh-oauth-key) => #f)
) ;let

;; 3. 残留钩子清除：从 oauth provider 切到 api_key provider 后钩子必须移除
(write-auth! (oauth-json (+ (pi-current-time-millis) 3600000)))
(let* ((cfg-oauth (pi-sync-oauth-refresh-hook (make-cfg "kimi-coding") '()))
       (cfg-switched (pi-cfg-set cfg-oauth 'provider "google"))
      ) ;
  (check-true (pi-oauth-refresh-enabled? cfg-switched))
  (write-auth! "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"}}")
  (let ((cfg-synced (pi-sync-oauth-refresh-hook cfg-switched '())))
    (check-false (pi-oauth-refresh-enabled? cfg-synced))
  ) ;let
) ;let*

;; 4. 会话中途 /login：初始无凭据不注入，落盘 oauth 凭据后重同步必须注入
(write-auth! "{}")
(let ((cfg (pi-sync-oauth-refresh-hook (make-cfg "kimi-coding") '())))
  (check-false (pi-oauth-refresh-enabled? cfg))
  (write-auth! (oauth-json (+ (pi-current-time-millis) 3600000)))
  (check-true (pi-oauth-refresh-enabled? (pi-sync-oauth-refresh-hook cfg '())))
) ;let

;; 5. 无 auth.json：不注入且不抛异常
(rmtree TMP-DIR)
(path-mkdir TMP-DIR :parents #t :exist-ok #t)
(let ((cfg (pi-sync-oauth-refresh-hook (make-cfg "kimi-coding") '())))
  (check-false (pi-oauth-refresh-enabled? cfg))
) ;let

;; 6. alist 形式 cfg 同样支持
(write-auth! (oauth-json (+ (pi-current-time-millis) 3600000)))
(let ((cfg (pi-sync-oauth-refresh-hook
             (list (cons 'config-dir TMP-DIR) (cons 'provider "kimi-coding"))
             '()
           ) ;pi-sync-oauth-refresh-hook
      ) ;cfg
     ) ;
  (check-true (pi-oauth-refresh-enabled? cfg))
) ;let

;; 7. 省略 opt-env：取进程环境变量，oauth 判定不受影响
(let ((cfg (pi-sync-oauth-refresh-hook (make-cfg "kimi-coding"))))
  (check-true (pi-oauth-refresh-enabled? cfg))
) ;let

(rmtree TMP-DIR)

(check-report)
