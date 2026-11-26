;; definition-contexts
;; 读取语法定义的上下文列表。
;;
;; 语法
;; ----
;; (definition-contexts def)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; list
;; alist (("ContextName" . <context-def>) ...)。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (definition-contexts (make-definition "X")) => '())

(let* ((ctx (make-context-def "Level0"))
       (d (make-definition "X" '() "Level0" (list (cons "Level0" ctx))))
      ) ;
  (check (= (length (definition-contexts d)) 1) => #t)
  (check
    (context-def-name (cdr (car (definition-contexts d))))
    =>
    "Level0"
  ) ;check
) ;let*

;; 内置 Scheme 定义包含核心上下文
(let ((d (load-syntax-definition "scheme")))
  (check (= (length (definition-contexts d)) 6) => #t)
) ;let

(check-report)
