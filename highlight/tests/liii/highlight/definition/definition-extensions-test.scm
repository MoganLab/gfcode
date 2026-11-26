;; definition-extensions
;; 读取语法定义适用的文件扩展名列表。
;;
;; 语法
;; ----
;; (definition-extensions def)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; list of string
;; 扩展名列表，如 '("*.scm" "*.ss")。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (definition-extensions (make-definition "X")) => '())
(check (definition-extensions (make-definition "X" '("*.scm" "*.ss")))
  =>
  '("*.scm" "*.ss")
) ;check

(check-report)
