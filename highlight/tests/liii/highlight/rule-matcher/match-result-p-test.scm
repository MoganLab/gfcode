;; match-result?
;; 判断对象是否为匹配结果。
;;
;; 语法
;; ----
;; (match-result? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是匹配结果返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight rule-matcher))

(check-set-mode! 'report-failed)

(check-true (match-result? (make-match-result)))
(check-true (match-result? (make-match-result #t 3)))
(check-false (match-result? "res"))
(check-false (match-result? '(#t 3)))
(check-false (match-result? #f))

(check-report)
