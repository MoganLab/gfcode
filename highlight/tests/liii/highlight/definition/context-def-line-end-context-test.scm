;; context-def-line-end-context
;; 读取上下文定义的行尾切换指令。
;;
;; 语法
;; ----
;; (context-def-line-end-context c)
;;
;; 参数
;; ----
;; c : context-def?
;; 上下文定义对象。
;;
;; 返回值
;; ----
;; list
;; 行尾切换指令，如 '(stay)、'(pop 1)。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (context-def-line-end-context (make-context-def "x")) => '(stay))
(check (context-def-line-end-context (make-context-def "x" "Normal" '(pop 1)))
  =>
  '(pop 1)
) ;check
(check (context-def-line-end-context (make-context-def "x" "Normal" '(pop 2
                                                                       "Target")))
  =>
  '(pop 2 "Target")
) ;check

(check-report)
