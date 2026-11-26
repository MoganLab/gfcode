;; rule-context-target
;; 读取规则的上下文切换指令。
;;
;; 语法
;; ----
;; (rule-context-target r)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; 返回值
;; ----
;; list
;; 切换指令，如 '(stay)、'(push "x")、'(pop 1)。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check (rule-context-target (make-rule 'detect-char "Normal" '(stay) #\())
  =>
  '(stay)
) ;check
(check (rule-context-target (make-rule 'detect-char "String" '(push "string") #\"))
  =>
  '(push "string")
) ;check
(check (rule-context-target (make-rule 'detect-char "Normal" '(pop 1) #\)))
  =>
  '(pop 1)
) ;check
(check (rule-context-target (make-rule 'detect-2chars "Comment" '(pop 2
                                                                   "Target") (cons #\| #\#))
       ) ;rule-context-target
  =>
  '(pop 2 "Target")
) ;check

(check-report)
