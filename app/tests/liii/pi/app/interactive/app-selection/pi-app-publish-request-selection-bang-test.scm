;; pi-app-publish-request-selection!
;; 发布一次完整请求选择快照到 request-selection-chan（latest-wins）。
;;
;; 语法
;; ----
;; (pi-app-publish-request-selection! app)
;;
;; 参数
;; ----
;; app : pi-app?
;;
;; 返回值
;; ----
;; unspecified

(import (scheme base)
  (liii check)
  (liii go)
  (liii tui)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive app-selection)
) ;import

(check-set-mode! 'report-failed)

;; 1. 发布一次快照：通道收到 (provider model thinking-level explicit?)
(let* ((app (make-pi-app
              :terminal       (make-virtual-terminal :width 80 :height 24)
              :provider       "google"
              :model          "gemini-3.8-flash"
              :thinking-level "high"
            ) ;make-pi-app
       ) ;app
      ) ;
  (pi-app-publish-request-selection! app)
  (check (chan-try-recv! (pi-app-request-selection-chan app) #f)
    =>
    '("google" "gemini-3.8-flash" "high" #f)
  ) ;check
) ;let*

;; 2. 连续发布两次：latest-wins，通道里只剩最后一项
(let* ((app (make-pi-app
              :terminal       (make-virtual-terminal :width 80 :height 24)
              :provider       "google"
              :model          "A"
              :thinking-level "medium"
            ) ;make-pi-app
       ) ;app
      ) ;
  (pi-app-publish-request-selection! app)
  (%pi-app-model-set! app "B")
  (pi-app-publish-request-selection! app)
  ;; 第一次快照被排空丢弃
  (check (chan-try-recv! (pi-app-request-selection-chan app) #f)
    =>
    '("google" "B" "medium" #f)
  ) ;check
  (check (chan-try-recv! (pi-app-request-selection-chan app) #f) => #f)
) ;let*

;; 3. 通道为空时发布后再次读取为空
(let* ((app (make-pi-app
              :terminal       (make-virtual-terminal :width 80 :height 24)
              :provider       "zai"
              :model          "glm-5"
              :thinking-level "low"
            ) ;make-pi-app
       ) ;app
      ) ;
  (pi-app-publish-request-selection! app)
  (chan-try-recv! (pi-app-request-selection-chan app) #f)
  (check (chan-try-recv! (pi-app-request-selection-chan app) #f) => #f)
) ;let*

(check-report)
