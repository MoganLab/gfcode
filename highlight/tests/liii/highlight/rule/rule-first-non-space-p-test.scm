;; rule-first-non-space?
;; 读取规则是否仅允许在行首第一个非空白字符处匹配。
;;
;; 语法
;; ----
;; (rule-first-non-space? r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; boolean
;; 有限制时返回 #t。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check-false (rule-first-non-space? (make-rule 'detect-char "Normal" '(stay) #\())
) ;check-false
(check-true (rule-first-non-space? (make-rule 'string-detect "Region" '(stay) "BEGIN" #f #t)
            ) ;rule-first-non-space?
) ;check-true

(check-report)
