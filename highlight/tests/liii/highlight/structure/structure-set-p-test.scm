;; structure-set?
;; 判断对象是否为结构集合。
;;
;; 语法
;; ----
;; (structure-set? value)
;;
;; 参数
;; ----
;; value : any
;;
;; 返回值
;; -----
;; boolean

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check-true (structure-set? (make-structure-set)))
(check-false (structure-set? '()))

(check-report)
