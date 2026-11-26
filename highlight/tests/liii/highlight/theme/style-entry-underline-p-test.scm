;; style-entry-underline?
;; 读取样式是否有下划线。
;;
;; 语法
;; ----
;; (style-entry-underline? s)
;;
;; 参数
;; ----
;; s : style-entry?
;; 样式属性对象。
;;
;; 返回值
;; ----
;; boolean
;; 有下划线返回 #t。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check-true (style-entry-underline? (make-style-entry #f #f #f #f #t)))
(check-false (style-entry-underline? (make-style-entry)))
;; Breeze Dark 的 Error 样式带下划线
(check-true (style-entry-underline? (theme-text-style (default-breeze-dark-theme) "Error"))
) ;check-true

(check-report)
