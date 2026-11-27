;; structure-definition-children
;; 获取嵌套结构允许的子结构名称。
;;
;; 语法
;; ----
;; (structure-definition-children definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; list of string

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(let ((list-def (make-structure-definition "list"
                  'list
                  'nested
                  "open"
                  "close"
                  '()
                  '("list" "atom")
                ) ;make-structure-definition
      ) ;list-def
     ) ;
  (check (structure-definition-children list-def) => '("list" "atom"))
) ;let

(check-report)
