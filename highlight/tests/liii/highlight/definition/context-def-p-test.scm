;; context-def?
;; 判断对象是否为上下文定义。
;;
;; 语法
;; ----
;; (context-def? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是上下文定义返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check-true (context-def? (make-context-def "Level0")))
(check-false (context-def? "Level0"))
(check-false (context-def? '("Level0")))
(check-false (context-def? #f))

(check-report)
