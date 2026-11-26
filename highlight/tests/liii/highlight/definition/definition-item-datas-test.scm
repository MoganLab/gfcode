;; definition-item-datas
;; 读取语法定义的 itemData 映射表。
;;
;; 语法
;; ----
;; (definition-item-datas def)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; list
;; alist (("ItemName" . defStyleName) ...)。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (definition-item-datas (make-definition "X")) => '())

(let ((d (make-definition "X" '() "Level0" '() (list (cons "Keyword" "Keyword")))))
  (check (= (length (definition-item-datas d)) 1) => #t)
  (check (cdr (car (definition-item-datas d))) => "Keyword")
) ;let

(check-report)
