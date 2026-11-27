;; structure-definition-role
;; 获取公开结构角色。
;;
;; 语法
;; ----
;; (structure-definition-role definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; symbol

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-definition-role (make-structure-definition "h" 'heading 'line "open")
       ) ;structure-definition-role
  =>
  'heading
) ;check

(check-report)
