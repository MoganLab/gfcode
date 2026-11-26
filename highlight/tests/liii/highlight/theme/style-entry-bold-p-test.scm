;; style-entry-bold?
;; 读取样式是否加粗。
;;
;; 语法
;; ----
;; (style-entry-bold? s)
;;
;; 参数
;; ----
;; s : style-entry?
;; 样式属性对象。
;;
;; 返回值
;; ----
;; boolean
;; 加粗返回 #t。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check-true (style-entry-bold? (make-style-entry #f #f #t)))
(check-false (style-entry-bold? (make-style-entry)))
;; Breeze Dark 的 Keyword 样式是加粗的
(check-true (style-entry-bold? (theme-text-style (default-breeze-dark-theme) "Keyword"))
) ;check-true

(check-report)
