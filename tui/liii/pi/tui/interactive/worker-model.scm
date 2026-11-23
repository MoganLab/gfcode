;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;
;;

;; 模型选择与请求前刷新逻辑：独立于 jobs-chan 的“最新请求选择”通道，
;; 在每次新 Provider 请求前解析最新选择并派生完整 effective-cfg。
;; 把该逻辑独立出来避免继续膨胀已接近 450 行上限的 worker.scm。
(define-library (liii pi tui interactive worker-model)
  (import (scheme base)
    (scheme write)
    (liii go)
    (liii list)
    (liii string)
    (liii pi ai config model-metadata)
    (liii pi ai models meta)
    (liii pi ai models route)
    (liii pi code config)
  ) ;import
  (export pi-make-effective-cfg-box
    pi-effective-cfg-ref
    pi-effective-cfg-set!
    pi-worker-make-prepare-request
    pi-worker-apply-selection
    ;; worker 线程重新求值调用链上的助手须导出
    pi-worker-merge-model
  ) ;export
  (begin

    ;; runtime/effective-cfg 容器：贯穿同一 Worker 的多个 job，
    ;; 每次请求前由 prepare-request 更新，避免回到 run 启动时的旧配置。
    ;; 用 vector(1) 表示可变 box，兼容线程间共享语义。
    (define (pi-make-effective-cfg-box initial-cfg)
      (vector initial-cfg)
    ) ;define

    (define (pi-effective-cfg-ref box)
      (vector-ref box 0)
    ) ;define

    (define (pi-effective-cfg-set! box cfg)
      (vector-set! box 0 cfg)
    ) ;define

    ;; 把一条选择快照 (provider model-id thinking-level thinking-level-explicit?)
    ;; 应用到 base-cfg，派生完整配置。跨 provider 时执行 augment-pi-config，
    ;; 确保 provider-api、认证、请求头、代理及上下文窗口同步更新。
    (define (pi-worker-apply-selection base-cfg selection parsed)
      (let* ((provider (car selection))
             (model-id (cadr selection))
             (tl (caddr selection))
             (explicit? (if (>= (length selection) 4) (cadddr selection) #f))
             (old-provider (pi-cfg-ref base-cfg 'provider))
             ;; 先应用 thinking（同 provider 内切换不触发 augment）
             (cfg-tl
               (pi-cfg-merge base-cfg
                 (list (cons 'thinking-level tl)
                   (cons 'thinking-level-explicit? (if explicit? #t #f))
                 ) ;list
               ) ;pi-cfg-merge
             ) ;cfg-tl
             (cfg-model (pi-worker-merge-model cfg-tl provider model-id))
            ) ;
        (if (equal? provider old-provider)
          cfg-model
          (augment-pi-config cfg-model parsed)
        ) ;if
      ) ;let*
    ) ;define

    ;; 覆盖 cfg 的模型相关项（会话内 /model 切换后立即生效，对齐上游 setModel）
    (define (pi-worker-merge-model cfg provider model-id)
      (let* ((config-dir (pi-cfg-config-dir cfg))
             (models-store (pi-cfg-ref cfg 'models-store '()))
             (auth (pi-load-auth config-dir))
             (api-key (pi-resolve-provider-key provider auth '() config-dir))
             (raw-meta (pi-resolve-model-metadata provider model-id models-store))
             (meta (pi-ensure-catalog-meta raw-meta provider model-id models-store))
             (supports (pi-model-supports-thinking? models-store provider model-id))
            ) ;
        ;; 1404：切模（含同 provider）后按新 provider 重同步 oauth 401
        ;; 刷新钩子：切到 oauth provider 时注入，切走时清除残留钩子。
        ;; 否则同 provider 切模不走 augment，会话中途 /login 后钩子缺失，
        ;; 401 无法强制刷新重试。
        (pi-sync-oauth-refresh-hook
          (pi-cfg-merge cfg
            (list (cons 'provider provider)
              (cons 'provider-api (pi-cfg-provider-api cfg provider model-id))
              (cons 'headers
                (pi-resolve-request-headers models-store provider model-id api-key)
              ) ;cons
              (cons 'model-id model-id)
              (cons 'model-meta meta)
              (cons 'api-key api-key)
              (cons 'supports-thinking supports)
              (cons 'proxy-url (pi-cfg-provider-proxy cfg provider))
            ) ;list
          ) ;pi-cfg-merge
        ) ;pi-sync-oauth-refresh-hook
      ) ;let*
    ) ;define

    ;; 排空 request-selection-chan，返回最后一项选择快照；通道为空返回 #f。
    (define (%drain-last-selection chan)
      (let loop
        ((last #f))
        (let ((v (catch #t (lambda () (chan-try-recv! chan #f)) (lambda args #f))))
          (if (and v (pair? v)) (loop v) last)
        ) ;let
      ) ;let
    ) ;define

    ;; 构造 prepare-request 过程，安装到 cfg 供 Agent 层在每次新请求前调用。
    ;; 行为：
    ;;   1. 排空 request-selection-chan（latest-wins），取最后一项选择。
    ;;   2. 有新选择时派生完整 effective-cfg 并保存到 box；无则沿用 box 中的当前值。
    ;;   3. 返回本次有效的 cfg。
    ;; 不回退到 run 启动时的旧配置；派生或认证失败由调用方异常路径处理。
    (define (pi-worker-make-prepare-request eff-box request-selection-chan parsed)
      (lambda (cfg)
        (let ((selection (%drain-last-selection request-selection-chan)))
          (if (pair? selection)
            (let ((new-cfg (pi-worker-apply-selection (pi-effective-cfg-ref eff-box) selection parsed)
                  ) ;new-cfg
                 ) ;
              (pi-effective-cfg-set! eff-box new-cfg)
              new-cfg
            ) ;let
            (pi-effective-cfg-ref eff-box)
          ) ;if
        ) ;let
      ) ;lambda
    ) ;define

  ) ;begin
) ;define-library
