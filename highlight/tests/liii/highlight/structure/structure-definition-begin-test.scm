;; structure-definition-begin
;; 获取结构开始事件。
;;
;; 语法
;; ----
;; (structure-definition-begin definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; string

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-definition-begin (make-structure-definition "h" 'heading 'line "heading-open")
       ) ;structure-definition-begin
  =>
  "heading-open"
) ;check

(check-report)
