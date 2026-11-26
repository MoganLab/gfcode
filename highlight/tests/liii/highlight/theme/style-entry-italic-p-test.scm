;; style-entry-italic?
;; 读取样式是否斜体。
;;
;; 语法
;; ----
;; (style-entry-italic? s)
;;
;; 参数
;; ----
;; s : style-entry?
;; 样式属性对象。
;;
;; 返回值
;; ----
;; boolean
;; 斜体返回 #t。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check-true (style-entry-italic? (make-style-entry #f #f #f #t)))
(check-false (style-entry-italic? (make-style-entry)))

(check-report)
