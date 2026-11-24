;; pi-app-exit-requested?
;; 获取应用是否已请求退出主循环（/exit 命令置位）。
;;
;; 语法
;; ----
;; (pi-app-exit-requested? app)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; 返回值
;; ------
;; boolean?
;; 是否已请求退出。

(import (scheme base)
  (liii check)
  (liii tui)
  (liii pi app interactive app)
  (liii pi app interactive state)
) ;import

(check-set-mode! 'report-failed)

;; 1. 初始为 #f
(let ((app (make-pi-app :terminal (make-virtual-terminal :width 80 :height 24))))
  (check (pi-app-exit-requested? app) => #f)
) ;let

;; 2. 置位后变为 #t
(let ((app (make-pi-app :terminal (make-virtual-terminal :width 80 :height 24))))
  (%pi-app-exit-requested-set! app #t)
  (check (pi-app-exit-requested? app) => #t)
) ;let

(check-report)
