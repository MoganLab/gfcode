;; rule-data
;; 读取规则的专有负载数据。
;;
;; 语法
;; ----
;; (rule-data r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; any
;; 依规则类型而异：字符、字符串、cons 等；未指定时为 #f。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check (rule-data (make-rule 'detect-char "Normal" '(stay) #\()) => #\()
(check (rule-data (make-rule 'detect-2chars "Comment" '(stay) (cons #\# #\|)))
  =>
  (cons #\# #\|)
) ;check
(check (rule-data (make-rule 'any-char "Operator" '(stay) "{}[]")) => "{}[]")
(check (rule-data (make-rule 'string-detect "Region" '(stay) "BEGIN"))
  =>
  "BEGIN"
) ;check
(check (rule-data (make-rule 'detect-spaces "Normal" '(stay))) => #f)

(check-report)
