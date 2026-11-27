;; structure-definition-include-begin?
;; 查询片段是否包含开始标记。
;;
;; 语法
;; ----
;; (structure-definition-include-begin? definition)
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
(check-true (structure-definition-include-begin? (make-structure-definition "h" 'heading 'line "open")
            ) ;structure-definition-include-begin?
) ;check-true
(let ((code (make-structure-definition "code"
              'code-block
              'delimited
              "open"
              "close"
              '()
              '()
              #f
            ) ;make-structure-definition
      ) ;code
     ) ;
  (check-false (structure-definition-include-begin? code))
) ;let

(check-report)
