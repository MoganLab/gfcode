;; style-entry-text-color
;; 读取样式的前景色。
;;
;; 语法
;; ----
;; (style-entry-text-color s)
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

(check (style-entry-text-color (make-style-entry '(207 207 194)))
  =>
  '(207 207 194)
) ;check
(check (style-entry-text-color (make-style-entry)) => #f)

(check-report)
