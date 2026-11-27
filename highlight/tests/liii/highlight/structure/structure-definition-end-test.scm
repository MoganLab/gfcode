;; structure-definition-end
;; 获取结构结束事件。
;;
;; 语法
;; ----
;; (structure-definition-end definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; string | #f；line 结构为 #f。

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-definition-end (make-structure-definition "h" 'heading 'line "open"))
  =>
  #f
) ;check
(check (structure-definition-end (make-structure-definition "list" 'list 'nested "open" "close")
       ) ;structure-definition-end
  =>
  "close"
) ;check

(check-report)
