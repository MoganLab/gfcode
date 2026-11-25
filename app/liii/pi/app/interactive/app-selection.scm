;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 独立于 jobs-chan 的“最新请求选择”通道发布辅助（latest-wins）。
;; 集中发布规则，避免 /model 与 /thinking 各复制一套导致互相覆盖。
(define-library (liii pi app interactive app-selection)
  (export pi-app-publish-request-selection!)
  (import (scheme base) (liii go) (liii tui) (liii pi app interactive state))
  (begin

    ;; 发布一次完整请求选择快照到 request-selection-chan（latest-wins）：
    ;; 发布前先排空通道内未消费的旧快照，保证连续切换 A->B->C 时下一次请求只看到 C。
    ;; /model 与 /thinking 共用此出口，避免较早的 /model 快照覆盖较新的 /thinking 快照。
    ;; 发布不得长时间阻塞 TUI；通道关闭等异常以错误卡片提示，不静默吞掉。
    (define (pi-app-publish-request-selection! app)
      (let ((ch (pi-app-request-selection-chan app)))
        ;; 先排空旧快照：latest-wins
        (let drain
          ()
          (let ((old (catch #t (lambda () (chan-try-recv! ch #f)) (lambda args #f))))
            (when old
              (drain)
            ) ;when
          ) ;let
        ) ;let
        (catch #t
          (lambda ()
            (chan-send! ch
              (list (pi-app-provider app)
                (pi-app-model app)
                (pi-app-thinking-level app)
                (pi-app-thinking-level-explicit? app)
              ) ;list
              1000
            ) ;chan-send!
          ) ;lambda
          (lambda (tag . args)
            (container-add! (%pi-app-chat app)
              (make-tool-card "session" '() 'error "Failed to publish model selection")
            ) ;container-add!
          ) ;lambda
        ) ;catch
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
