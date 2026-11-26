;; definition-find-context
;; 按名称查找上下文定义。
;;
;; 语法
;; ----
;; (definition-find-context def name)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; name : string
;; 上下文名称。
;;
;; 返回值
;; ----
;; <context-def> 或 #f
;; 找到返回上下文定义，否则 #f。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(let ((d (load-syntax-definition "scheme")))
  (check-true (not (not (definition-find-context d "Level0"))))
  (check-true (not (not (definition-find-context d "comment"))))
  (check-true (not (not (definition-find-context d "string"))))
  (check (definition-find-context d "no-such-context") => #f)
) ;let

(check (definition-find-context (make-definition "X") "Level0") => #f)

(check-report)
