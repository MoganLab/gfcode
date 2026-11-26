;; rule-attribute
;; 读取规则匹配后输出的 itemData 名称。
;;
;; 语法
;; ----
;; (rule-attribute r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; string
;; itemData 名称，如 "Keyword"。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check (rule-attribute (make-rule 'detect-char "Normal" '(stay) #\())
  =>
  "Normal"
) ;check
(check (rule-attribute (make-rule 'detect-2chars "Comment" '(stay) (cons #\# #\|)))
  =>
  "Comment"
) ;check
(check
  (rule-attribute (make-rule 'keyword "Keyword" '(stay) (cons '("if") #f)))
  =>
  "Keyword"
) ;check
(check (rule-attribute (make-rule 'int "DecVal" '(stay) #f)) => "DecVal")

(check-report)
