;; rule?
;; 判断对象是否为高亮规则。
;;
;; 语法
;; ----
;; (rule? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是规则对象返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check-true (rule? (make-rule 'detect-char "Normal" '(stay) #\()))
(check-true
  (rule? (make-rule 'keyword "Keyword" '(stay) (cons '("if") #f)))
) ;check-true
(check-false (rule? "not-a-rule"))
(check-false (rule? 42))
(check-false (rule? '()))
(check-false (rule? #f))

(check-report)
