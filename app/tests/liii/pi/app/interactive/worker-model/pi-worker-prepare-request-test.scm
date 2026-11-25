;; pi-worker-prepare-request
;; 测试 Worker 请求前刷新逻辑：排空 request-selection-chan（latest-wins）、
;; 派生完整 effective-cfg、跨 provider 执行 augment、thinking 与显式标志更新。
;;
;; 语法
;; ----
;; (pi-worker-make-prepare-request eff-box request-selection-chan parsed)
;;
;; 参数
;; ----
;; eff-box : vector?，effective-cfg 容器
;; request-selection-chan : chan?，最新请求选择通道
;; parsed : list?，命令行参数（供 augment-pi-config 使用）
;;
;; 返回值
;; ----
;; procedure?，prepare-request 过程

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii go)
  (liii pi ai config model-metadata)
  (liii pi code cli args)
  (liii pi code config)
  (liii pi app interactive worker-model)
) ;import

(check-set-mode! 'report-failed)

(define TMP-AGENT-DIR
  (path->string (path-join (path-temp-dir) "pi-worker-prepare-request-test"))
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
         (parsed (parse-pi-args '()))
         (cfg (resolve-pi-config parsed env))
        ) ;
    (values cfg parsed)
  ) ;let*
) ;define

;; -----------------------------------------------------------------------------
;; 测试项 1: 通道为空时沿用 effective-cfg，不回退旧模型
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
         (result (prepare cfg))
        ) ;
    (check (pi-cfg-ref result 'provider) => (pi-cfg-ref cfg 'provider))
    (check (pi-cfg-ref result 'model-id) => (pi-cfg-ref cfg 'model-id))
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 2: 多个待消费快照只应用最后一个（latest-wins）
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 16))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
        ) ;
    (chan-send! chan (list "anthropic" "claude-haiku-4-5" "high" #f) 1000)
    (chan-send! chan (list "google" "gemini-2.5-pro" "low" #f) 1000)
    (let ((result (prepare cfg)))
      (check (pi-cfg-ref result 'provider) => "google")
      (check (pi-cfg-ref result 'model-id) => "gemini-2.5-pro")
      (check (pi-cfg-ref result 'thinking-level) => "low")
    ) ;let
    ;; 通道已排空
    (check (chan-try-recv! chan #f) => #f)
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 3: 跨 provider 切换执行 augment：provider-api 与认证同步更新
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
        ) ;
    (chan-send! chan (list "anthropic" "claude-haiku-4-5" "high" #t) 1000)
    (let ((result (prepare cfg)))
      (check (pi-cfg-ref result 'provider) => "anthropic")
      (check (pi-cfg-ref result 'provider-api) => "anthropic-messages")
      (check (pi-cfg-ref result 'api-key) => "fixture-anthropic-key")
      (check (pi-cfg-ref result 'model-id) => "claude-haiku-4-5")
      (check (pi-cfg-ref result 'thinking-level) => "high")
      (check (pi-cfg-ref result 'thinking-level-explicit?) => #t)
      (check-true (pi-model-metadata? (pi-cfg-ref result 'model-meta)))
    ) ;let
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 4: 同 provider 切换只更新 model-id/model-meta，不触发 augment
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
         (old-provider (pi-cfg-ref cfg 'provider))
         (old-api (pi-cfg-ref cfg 'provider-api))
        ) ;
    (chan-send! chan (list "google" "gemini-2.5-pro" "medium" #f) 1000)
    (let ((result (prepare cfg)))
      (check (pi-cfg-ref result 'provider) => "google")
      (check (pi-cfg-ref result 'model-id) => "gemini-2.5-pro")
      ;; 同 provider 不改变 provider-api
      (check (pi-cfg-ref result 'provider-api) => old-api)
    ) ;let
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 5: 连续两次 prepare：第二次通道为空时沿用第一次的 effective-cfg
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
        ) ;
    (chan-send! chan (list "anthropic" "claude-haiku-4-5" "high" #f) 1000)
    (let ((r1 (prepare cfg)))
      (check (pi-cfg-ref r1 'provider) => "anthropic")
    ) ;let
    ;; 第二次通道为空：沿用 eff-box 中已保存的 anthropic 配置，不回退 google
    (let ((r2 (prepare cfg)))
      (check (pi-cfg-ref r2 'provider) => "anthropic")
      (check (pi-cfg-ref r2 'model-id) => "claude-haiku-4-5")
    ) ;let
  ) ;let*
) ;let*-values

(rmtree TMP-AGENT-DIR)

(check-report)
