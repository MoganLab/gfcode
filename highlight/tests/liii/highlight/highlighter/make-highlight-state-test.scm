;; make-highlight-state
;; 构造高亮引擎跨行状态。
;;
;; 语法
;; ----
;; (make-highlight-state)
;; (make-highlight-state stack)
;;
;; 参数
;; ----
;; stack : list (可选)
;; 上下文名称栈（栈顶在 car），默认 '("Level0")。
;;
;; 返回值
;; ----
;; <highlight-state>
;; 高亮状态对象。

(import (scheme base) (liii check) (liii highlight highlighter))

(check-set-mode! 'report-failed)

(let ((s (make-highlight-state)))
  (check (highlight-state-stack s) => '("Level0"))
) ;let

(let ((s (make-highlight-state '("string" "Level0"))))
  (check (highlight-state-stack s) => '("string" "Level0"))
) ;let

(check-report)
