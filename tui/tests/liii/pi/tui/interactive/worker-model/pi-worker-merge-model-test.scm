;; pi-worker-merge-model
;; 覆盖 cfg 的模型相关项（会话内 /model 切换后立即生效），并按新
;; provider 重同步 oauth 401 刷新钩子：切到 oauth provider 注入，
;; 切走清除残留钩子（同 provider 切模不走 augment 也须同步）。
;;
;; 语法
;; ----
;; (pi-worker-merge-model cfg provider model-id) -> cfg
;;
;; 参数
;; ----
;; cfg : pi-config?
;; 基准配置（含 config-dir / models-store）。
;;
;; provider : string?
;; 目标 provider。
;;
;; model-id : string?
;; 目标模型 id。
;;
;; 返回值
;; ----
;; cfg
;; 覆盖 provider/model-id/api-key/headers 等模型相关项后的配置。

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii pi ai keyring)
  (liii pi ai time)
  (liii pi code cli args)
  (liii pi code config)
  (liii pi tui interactive worker-model)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-worker-merge-model-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
  (string-append "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"},"
    "\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"old-acc\","
    "\"refresh\":\"stub-refresh-token\",\"expires\":"
    (number->string (+ (pi-current-time-millis) 3600000))
    "}}"
  ) ;string-append
) ;path-write-text

(define env (list (cons "PI_CODING_AGENT_DIR" TMP-DIR)))

;; 1. 跨 provider 切到 oauth provider：模型项覆盖且注入 401 刷新钩子
(let* ((cfg (resolve-pi-config (parse-pi-args '()) env))
       (cfg* (pi-worker-merge-model cfg "kimi-coding" "k3.1-pro"))
      ) ;
  (check (pi-cfg-ref cfg* 'provider) => "kimi-coding")
  (check (pi-cfg-ref cfg* 'model-id) => "k3.1-pro")
  (check-true (pi-oauth-refresh-enabled? cfg*))
  ;; 原 cfg 不被破坏（google 无 oauth 凭据无钩子）
  (check-false (pi-oauth-refresh-enabled? cfg))
) ;let*

;; 2. 从 oauth provider 切走：残留钩子必须清除，否则非 oauth 的 401
;;    会误触发刷新
(let* ((cfg (resolve-pi-config (parse-pi-args '()) env))
       (cfg-kimi (pi-worker-merge-model cfg "kimi-coding" "k3.1-pro"))
       (cfg-google (pi-worker-merge-model cfg-kimi "google" "gemini-3.8-flash"))
      ) ;
  (check (pi-cfg-ref cfg-google 'provider) => "google")
  (check (pi-cfg-ref cfg-google 'api-key) => "fixture-google-key")
  (check-false (pi-oauth-refresh-enabled? cfg-google))
) ;let*

;; 3. 会话中途 /login：初始无 kimi 凭据（无钩子），auth.json 落盘 oauth
;;    凭据后同 provider 切模必须补注入钩子（不走 augment 的路径）
(let ((no-kimi-dir (path->string (path-join (path-temp-dir) "pi-worker-merge-model-login-test")))
      ) ;
  (when (file-exists? no-kimi-dir)
    (rmtree no-kimi-dir)
  ) ;when
  (path-mkdir no-kimi-dir :parents #t :exist-ok #t)
  (path-write-text (path->string (path-join (path no-kimi-dir) (path "auth.json")))
    "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"}}"
  ) ;path-write-text
  (let* ((env2 (list (cons "PI_CODING_AGENT_DIR" no-kimi-dir)))
         (cfg (resolve-pi-config (parse-pi-args '()) env2))
         (cfg-kimi (pi-worker-merge-model cfg "kimi-coding" "k3.1-pro"))
        ) ;
    (check-false (pi-oauth-refresh-enabled? cfg-kimi))
    ;; 模拟 /login kimi-coding 落盘 oauth 凭据
    (path-write-text (path->string (path-join (path no-kimi-dir) (path "auth.json")))
      (string-append "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"},"
        "\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"old-acc\","
        "\"refresh\":\"stub-refresh-token\",\"expires\":"
        (number->string (+ (pi-current-time-millis) 3600000))
        "}}"
      ) ;string-append
    ) ;path-write-text
    (let ((cfg-after (pi-worker-merge-model cfg-kimi "kimi-coding" "k3.1-pro")))
      (check-true (pi-oauth-refresh-enabled? cfg-after))
    ) ;let
  ) ;let*
  (rmtree no-kimi-dir)
) ;let

(rmtree TMP-DIR)

(check-report)
