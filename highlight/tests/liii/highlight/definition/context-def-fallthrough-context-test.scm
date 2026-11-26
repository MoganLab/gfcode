;; context-def-fallthrough-context
;; 读取上下文定义的 fallthrough 切换指令。
;;
;; 语法
;; ----
;; (context-def-fallthrough-context c)
;;
;; 参数
;; ----
;; c : context-def?
;; 上下文定义对象。
;;
;; 返回值
;; ----
;; list 或 #f
;; 无规则匹配时的切换指令；无则为 #f。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (context-def-fallthrough-context (make-context-def "x")) => #f)
(check (context-def-fallthrough-context (make-context-def "x" "Normal" '(stay) '(push "Other"))
       ) ;context-def-fallthrough-context
  =>
  '(push "Other")
) ;check

(check-report)
