;; pi-worker-make-prepare-request
;; 构造 prepare-request 过程：安装到 cfg 供 Agent 层在每次新请求前调用。
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
;; procedure?，prepare-request 过程（接收 cfg，返回本次有效 cfg）

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
  (path->string (path-join (path-temp-dir) "pi-worker-make-prepare-request-test"))
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
;; 测试项 1: 返回过程：调用后容器与返回值同步为最新选择派生的配置
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
        ) ;
    (check-true (procedure? prepare))
    (chan-send! chan (list "anthropic" "claude-haiku-4-5" "high" #f) 1000)
    (let ((result (prepare cfg)))
      ;; 返回值即容器中的最新 effective-cfg
      (check result => (pi-effective-cfg-ref eff-box))
      (check (pi-cfg-ref result 'provider) => "anthropic")
    ) ;let
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 2: 通道为空时返回容器当前值，不回退到传入的旧 cfg
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
        ) ;
    ;; 先切换到 anthropic，再以原始 google cfg 调用：不回退到旧 cfg
    (chan-send! chan (list "anthropic" "claude-haiku-4-5" "high" #f) 1000)
    (prepare cfg)
    (let ((result (prepare cfg)))
      (check (pi-cfg-ref result 'provider) => "anthropic")
      (check (pi-cfg-ref result 'model-id) => "claude-haiku-4-5")
    ) ;let
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 3: 排空通道（latest-wins）：连续快照只应用最后一个，通道被清空
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-base-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 16))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
        ) ;
    (chan-send! chan (list "anthropic" "claude-haiku-4-5" "low" #f) 1000)
    (chan-send! chan (list "google" "gemini-2.5-pro" "high" #t) 1000)
    (let ((result (prepare cfg)))
      (check (pi-cfg-ref result 'provider) => "google")
      (check (pi-cfg-ref result 'model-id) => "gemini-2.5-pro")
      (check (pi-cfg-ref result 'thinking-level) => "high")
      (check (pi-cfg-ref result 'thinking-level-explicit?) => #t)
      ;; 通道已排空
      (check (chan-try-recv! chan #f) => #f)
    ) ;let
  ) ;let*
) ;let*-values

(rmtree TMP-AGENT-DIR)

(check-report)
