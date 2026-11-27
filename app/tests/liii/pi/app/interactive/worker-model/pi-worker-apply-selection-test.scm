;; pi-worker-apply-selection
;; 把一条选择快照 (provider model-id thinking-level thinking-level-explicit?)
;; 应用到 base-cfg 派生完整配置；跨 provider 时执行 augment-pi-config。
;;
;; 语法
;; ----
;; (pi-worker-apply-selection base-cfg selection parsed)
;;
;; 参数
;; ----
;; base-cfg : list?，基准配置
;; selection : list?，选择快照
;; parsed : list?，命令行参数（供 augment-pi-config 使用）
;;
;; 返回值
;; ----
;; list?，派生后的完整配置

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii pi ai config model-metadata)
  (liii pi code cli args)
  (liii pi code config)
  (liii pi app interactive worker-model)
) ;import

(check-set-mode! 'report-failed)

(define TMP-AGENT-DIR
  (path->string (path-join (path-temp-dir) "pi-worker-apply-selection-test"))
) ;define

(when (file-exists? TMP-AGENT-DIR)
  (rmtree TMP-AGENT-DIR)
) ;when

(path-mkdir TMP-AGENT-DIR :parents #t :exist-ok #t)
(path-write-text (path->string (path-join (path TMP-AGENT-DIR) (path "auth.json")))
  "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"},\"anthropic\":{\"type\":\"api_key\",\"key\":\"fixture-anthropic-key\"}}"
) ;path-write-text

(define (make-base-cfg)
  (let* ((env (list (cons "PI_CODING_AGENT_DIR" TMP-AGENT-DIR)))
         (parsed (parse-pi-args '("--provider" "google")))
         (cfg (resolve-pi-config parsed env))
        ) ;
    (values cfg parsed)
  ) ;let*
) ;define

;; -----------------------------------------------------------------------------
;; 测试项 1: 同 provider 切换：thinking 与显式标志随快照更新
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((provider (pi-cfg-ref cfg 'provider))
         (model-id (pi-cfg-ref cfg 'model-id))
         (result (pi-worker-apply-selection cfg (list provider model-id "high" #t) parsed)
         ) ;result
        ) ;
    (check (pi-cfg-ref result 'provider) => provider)
    (check (pi-cfg-ref result 'model-id) => model-id)
    (check (pi-cfg-ref result 'thinking-level) => "high")
    (check (pi-cfg-ref result 'thinking-level-explicit?) => #t)
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 2: 跨 provider 切换：provider/model/api/认证全部同步
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let ((result (pi-worker-apply-selection cfg
                  (list "anthropic" "claude-haiku-4-5" "medium" #f)
                  parsed
                ) ;pi-worker-apply-selection
        ) ;result
       ) ;
    (check (pi-cfg-ref result 'provider) => "anthropic")
    (check (pi-cfg-ref result 'provider-api) => "anthropic-messages")
    (check (pi-cfg-ref result 'model-id) => "claude-haiku-4-5")
    (check (pi-cfg-ref result 'api-key) => "fixture-anthropic-key")
    (check (pi-cfg-ref result 'thinking-level) => "medium")
    (check (pi-cfg-ref result 'thinking-level-explicit?) => #f)
    (check-true (pi-model-metadata? (pi-cfg-ref result 'model-meta)))
    ;; base-cfg 不被破坏
    (check (pi-cfg-ref cfg 'provider) => "google")
  ) ;let
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 3: 三元快照（无显式标志）按 #f 处理
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((provider (pi-cfg-ref cfg 'provider))
         (result (pi-worker-apply-selection cfg (list provider "gemini-2.5-pro" "low") parsed)
         ) ;result
        ) ;
    (check (pi-cfg-ref result 'model-id) => "gemini-2.5-pro")
    (check (pi-cfg-ref result 'thinking-level) => "low")
    (check (pi-cfg-ref result 'thinking-level-explicit?) => #f)
  ) ;let*
) ;let*-values

(rmtree TMP-AGENT-DIR)

(check-report)
