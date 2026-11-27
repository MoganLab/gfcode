;; definition-line-blocks
;; 获取 syntax JSON segments 中声明的行级 block 配置。
;;
;; 语法
;; ----
;; (definition-line-blocks def)
;;
;; 参数
;; ----
;; def : definition?
;;
;; 返回值
;; -----
;; line-block-set?；未声明时为无定义的空配置。

(import (scheme base) (liii check) (liii json) (liii highlight definition))

(check-set-mode! 'report-failed)

(let* ((d (load-syntax-definition "markdown"))
       (blocks (definition-line-blocks d))
       (defs (vector->list (json-ref blocks "definitions")))
      ) ;
  (check (json-ref-boolean blocks "blank-separator" #f) => #t)
  (check (length defs) => 3)
  (check (map (lambda (item) (json-ref-string item "role" "")) defs)
    =>
    '("list-item" "list-item" "code-block")
  ) ;check
) ;let*

(check
  (vector-length (json-ref (definition-line-blocks (make-definition "Tiny")) "definitions")
  ) ;vector-length
  =>
  0
) ;check

(check-report)
