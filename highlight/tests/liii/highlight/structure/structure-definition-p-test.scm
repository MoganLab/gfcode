;; structure-definition?
;; 判断对象是否为结构定义。
;;
;; 语法
;; ----
;; (structure-definition? value)
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
(check-true (structure-definition? (make-structure-definition "h" 'heading 'line "open"))
) ;check-true
(check-false (structure-definition? 'heading))

(check-report)
