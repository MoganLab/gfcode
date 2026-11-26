;; context-def-name
;; 读取上下文定义的名称。
;;
;; 语法
;; ----
;; (context-def-name c)
;;
;; 参数
;; ----
;; c : context-def?
;; 上下文定义对象。
;;
;; 返回值
;; ----
;; string
;; 上下文名称。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (context-def-name (make-context-def "Level0")) => "Level0")
(check (context-def-name (make-context-def "comment")) => "comment")

(check-report)
