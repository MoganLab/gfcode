;; style-entry-bg-color
;; 读取样式的背景色。
;;
;; 语法
;; ----
;; (style-entry-bg-color s)
;;
;; 参数
;; ----
;; s : style-entry?
;; 样式属性对象。
;;
;; 返回值
;; ----
;; list 或 #f
;; '(r g b) 或 #f。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check (style-entry-bg-color (make-style-entry #f '(77 33 34))) => '(77 33 34))
(check (style-entry-bg-color (make-style-entry)) => #f)

(check-report)
