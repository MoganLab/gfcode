;; context-def-attribute
;; 读取上下文定义的默认 itemData 名称。
;;
;; 语法
;; ----
;; (context-def-attribute c)
;;
;; 参数
;; ----
;; c : context-def?
;; 上下文定义对象。
;;
;; 返回值
;; ----
;; string
;; 默认 itemData 名称。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (context-def-attribute (make-context-def "x")) => "Normal")
(check (context-def-attribute (make-context-def "x" "Comment")) => "Comment")
(check (context-def-attribute (make-context-def "x" "String")) => "String")

(check-report)
