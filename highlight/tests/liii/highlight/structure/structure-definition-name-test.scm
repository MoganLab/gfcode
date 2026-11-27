;; structure-definition-name
;; 获取结构名称。
;;
;; 语法
;; ----
;; (structure-definition-name definition)
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
(check (structure-definition-name (make-structure-definition "list" 'list 'nested "open" "close")
       ) ;structure-definition-name
  =>
  "list"
) ;check

(check-report)
