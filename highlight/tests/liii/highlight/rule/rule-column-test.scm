;; rule-column
;; 读取规则限定的匹配列号。
;;
;; 语法
;; ----
;; (rule-column r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; integer
;; 列号；-1 表示不限制。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check (rule-column (make-rule 'detect-char "Normal" '(stay) #\()) => -1)
(check (rule-column (make-rule 'detect-char "Normal" '(stay) #\( #f #f 0)) => 0)
(check (rule-column (make-rule 'detect-char "Normal" '(stay) #\( #f #f 8)) => 8)

(check-report)
