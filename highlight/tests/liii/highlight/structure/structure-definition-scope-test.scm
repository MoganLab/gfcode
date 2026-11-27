;; structure-definition-scope
;; 获取结构范围类型。
;;
;; 语法
;; ----
;; (structure-definition-scope definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; symbol：line、delimited 或 nested。

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-definition-scope (make-structure-definition "h" 'heading 'line "open")
       ) ;structure-definition-scope
  =>
  'line
) ;check
(check (structure-definition-scope (make-structure-definition "code" 'code-block 'delimited "open" "close")
       ) ;structure-definition-scope
  =>
  'delimited
) ;check
(check (structure-definition-scope (make-structure-definition "list" 'list 'nested "open" "close")
       ) ;structure-definition-scope
  =>
  'nested
) ;check

(check-report)
