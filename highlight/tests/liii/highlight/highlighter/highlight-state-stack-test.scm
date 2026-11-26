;; highlight-state-stack
;; 读取高亮状态的上下文栈。
;;
;; 语法
;; ----
;; (highlight-state-stack s)
;;
;; 参数
;; ----
;; s : highlight-state?
;; 高亮状态对象。
;;
;; 返回值
;; ----
;; list of string
;; 上下文名称栈，栈顶在 car。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

(check (highlight-state-stack (make-highlight-state)) => '("Level0"))
(check (highlight-state-stack (make-highlight-state '("comment" "Level0")))
  =>
  '("comment" "Level0")
) ;check

;; 初始状态栈只有一个初始上下文
(check (highlight-state-stack (initial-highlight-state (load-syntax-definition "scheme"))
       ) ;highlight-state-stack
  =>
  '("Level0")
) ;check

(check-report)
