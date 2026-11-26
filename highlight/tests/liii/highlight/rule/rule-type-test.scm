;; rule-type
;; 读取规则的类型。
;;
;; 语法
;; ----
;; (rule-type r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; symbol
;; 规则类型符号。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check (rule-type (make-rule 'detect-char "Normal" '(stay) #\())
  =>
  'detect-char
) ;check
(check (rule-type (make-rule 'detect-2chars "Comment" '(stay) (cons #\# #\|)))
  =>
  'detect-2chars
) ;check
(check (rule-type (make-rule 'any-char "Operator" '(stay) "{}")) => 'any-char)
(check (rule-type (make-rule 'string-detect "Region" '(stay) "BEGIN"))
  =>
  'string-detect
) ;check
(check
  (rule-type (make-rule 'keyword "Keyword" '(stay) (cons '("if") #f)))
  =>
  'keyword
) ;check
(check (rule-type (make-rule 'int "DecVal" '(stay) #f)) => 'int)
(check (rule-type (make-rule 'detect-spaces "Normal" '(stay)))
  =>
  'detect-spaces
) ;check

(check-report)
