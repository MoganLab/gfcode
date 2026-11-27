;; definition-structures
;; 获取语法定义的语义结构集合。
;;
;; 语法
;; ----
;; (definition-structures definition)
;;
;; 参数
;; ----
;; definition : definition?
;; 语法定义对象。
;;
;; 返回值
;; -----
;; structure-set?
;; 结构集合；未声明 segments 时为空集合，高亮行为不变。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight structure)
) ;import

(check-set-mode! 'report-failed)

;; 默认空集合
(let ((d (make-definition "Tiny")))
  (check-true (structure-set? (definition-structures d)))
  (check (structure-set-structures (definition-structures d)) => '())
) ;let

;; 显式携带结构集合
(let* ((heading (make-structure-definition "heading" 'heading 'line "heading-open"))
       (set (make-structure-set :structures (list heading)))
       (d (make-definition "Demo" '() "Level0" '() '() set))
      ) ;
  (check (definition-structures d) => set)
) ;let*

(check-report)
