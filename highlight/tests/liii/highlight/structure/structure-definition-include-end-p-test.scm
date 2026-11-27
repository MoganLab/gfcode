;; structure-definition-include-end?
;; 查询片段是否包含结束标记。
;;
;; 语法
;; ----
;; (structure-definition-include-end? definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; boolean

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(let ((code (make-structure-definition "code"
              'code-block
              'delimited
              "open"
              "close"
              '()
              '()
              #t
              #f
            ) ;make-structure-definition
      ) ;code
     ) ;
  (check-false (structure-definition-include-end? code))
) ;let

(check-report)
