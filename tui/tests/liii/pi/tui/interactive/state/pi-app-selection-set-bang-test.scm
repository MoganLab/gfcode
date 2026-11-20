;; pi-app-selection-set!
;; 设置应用当前的选区范围对象。
;;
;; 语法
;; ----
;; (pi-app-selection-set! app sel)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;; sel : any
;; 选区范围对象。
;;
;; 返回值
;; -----
;; unspecified

(import (scheme base)
  (liii check)
  (liii tui)
  (liii pi tui interactive app)
  (liii pi tui interactive state)
  (liii pi tui interactive selection)
) ;import

(check-set-mode! 'report-failed)

(let* ((app (make-pi-app :terminal (make-virtual-terminal :width 80 :height 24)))
       (sel (make-selection-range '(2 . 2) '(6 . 6) #t))
      ) ;
  (pi-app-selection-set! app sel)
  (check (pi-app-selection app) => sel)
) ;let*

(check-report)
