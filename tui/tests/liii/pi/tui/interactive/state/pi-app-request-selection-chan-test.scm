;; pi-app-request-selection-chan
;; 获取应用状态字段 pi-app-request-selection-chan。
;;
;; 语法
;; ----
;; (pi-app-request-selection-chan app)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; 返回值
;; ----
;; any
;; 当前字段存储的状态值（chan? 或 #f）。

(import (scheme base)
  (liii check)
  (liii go)
  (liii tui)
  (liii pi tui interactive app)
  (liii pi tui interactive state)
) ;import

(check-set-mode! 'report-failed)

(let* ((ch (make-chan 8))
       (app (make-pi-app :terminal (make-virtual-terminal :width 80 :height 24)))
      ) ;
  (check-true (chan? (pi-app-request-selection-chan app)))
) ;let*

(check-report)
