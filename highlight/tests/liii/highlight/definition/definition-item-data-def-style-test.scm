;; definition-item-data-def-style
;; 查询 itemData 对应的样式名。
;;
;; 语法
;; ----
;; (definition-item-data-def-style def item-name)
;;
;; 参数
;; ----
;; def : definition?
;; 语法定义对象。
;;
;; item-name : string
;; itemData 名称。
;;
;; 返回值
;; ----
;; string
;; 样式名；未知名称原样返回。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(let ((def (load-syntax-definition "scheme")))
  (check (definition-item-data-def-style def "Keyword") => "Keyword")
  (check (definition-item-data-def-style def "Unknown") => "Unknown")
) ;let

(check-report)
