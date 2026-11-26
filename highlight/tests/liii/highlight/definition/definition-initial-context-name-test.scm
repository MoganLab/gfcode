;; definition-initial-context-name
;; 读取语法定义的初始上下文名称。
;;
;; 语法
;; ----
;; (definition-initial-context-name def)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; string
;; 初始上下文名称，如 "Level0"。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (definition-initial-context-name (make-definition "X")) => "Level0")
(check (definition-initial-context-name (make-definition "X" '() "Base"))
  =>
  "Base"
) ;check
(check (definition-initial-context-name (load-syntax-definition "scheme"))
  =>
  "Level0"
) ;check

(check-report)
