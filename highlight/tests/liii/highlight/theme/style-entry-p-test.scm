;; style-entry?
;; 判断对象是否为样式属性。
;;
;; 语法
;; ----
;; (style-entry? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是样式属性返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check-true (style-entry? (make-style-entry)))
(check-true (style-entry? (make-style-entry '(1 2 3))))
(check-false (style-entry? "style"))
(check-false (style-entry? '(1 2 3)))
(check-false (style-entry? #f))

(check-report)
