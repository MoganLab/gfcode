;; rule-look-ahead?
;; 读取规则是否为前瞻规则。
;;
;; 语法
;; ----
;; (rule-look-ahead? r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; boolean
;; 前瞻规则返回 #t（匹配时只切上下文不前进偏移）。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check-false (rule-look-ahead? (make-rule 'detect-char "Normal" '(stay) #\()))
(check-true (rule-look-ahead? (make-rule 'detect-char "String" '(push "s") #\" #t))
) ;check-true
(check-false (rule-look-ahead? (make-rule 'detect-char "String" '(push "s") #\" #f))
) ;check-false

(check-report)
