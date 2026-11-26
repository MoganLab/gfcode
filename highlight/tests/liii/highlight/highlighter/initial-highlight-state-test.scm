;; initial-highlight-state
;; 根据语法定义构造初始高亮状态。
;;
;; 语法
;; ----
;; (initial-highlight-state def)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; <highlight-state>
;; 栈内仅含初始上下文的状态。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

(let ((def (load-syntax-definition "scheme")))
  (let ((s (initial-highlight-state def)))
    (check-true (highlight-state? s))
    (check (highlight-state-stack s) => '("Level0"))
  ) ;let
) ;let

;; 自定义初始上下文名
(let ((s (initial-highlight-state (make-definition "X" '() "Base"))))
  (check (highlight-state-stack s) => '("Base"))
) ;let

(check-report)
