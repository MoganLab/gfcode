;; definition-name
;; 读取语法定义的语言名称。
;;
;; 语法
;; ----
;; (definition-name def)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; string
;; 语言名称。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (definition-name (make-definition "Scheme")) => "Scheme")
(check (definition-name (make-definition "JSON")) => "JSON")

(check-report)
