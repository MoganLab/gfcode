;; structure-set-structures
;; 获取结构定义列表。
;;
;; 语法
;; ----
;; (structure-set-structures structure-set)
;;
;; 参数
;; ----
;; structure-set : structure-set?
;;
;; 返回值
;; -----
;; list of structure-definition?

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(let* ((heading (make-structure-definition "h" 'heading 'line "open"))
       (set (make-structure-set :structures (list heading)))
      ) ;
  (check (structure-set-structures set) => (list heading))
) ;let*

(check-report)
