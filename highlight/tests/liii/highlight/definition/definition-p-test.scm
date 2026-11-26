;; definition?
;; 判断对象是否为语法定义。
;;
;; 语法
;; ----
;; (definition? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是语法定义返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check-true (definition? (make-definition "Scheme")))
(check-false (definition? "Scheme"))
(check-false (definition? (make-context-def "x")))
(check-false (definition? #f))

(check-report)
