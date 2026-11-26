;; make-definition
;; 构造完整语法定义对象。
;;
;; 语法
;; ----
;; (make-definition name)
;; (make-definition name extensions initial-context-name contexts item-datas)
;;
;; 参数
;; ----
;; name : string
;; 语言名称。
;;
;; extensions : list (可选)
;; 文件扩展名列表，默认 '()。
;;
;; initial-context-name : string (可选)
;; 初始上下文名称，默认 "Level0"。
;;
;; contexts : list (可选)
;; alist (("Name" . <context-def>) ...)，默认 '()。
;;
;; item-datas : list (可选)
;; alist (("ItemName" . style-name) ...)，默认 '()。
;;
;; 返回值
;; ----
;; <definition>
;; 语法定义对象。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(let ((d (make-definition "Scheme")))
  (check (definition-name d) => "Scheme")
  (check (definition-extensions d) => '())
  (check (definition-initial-context-name d) => "Level0")
  (check (definition-contexts d) => '())
  (check (definition-item-datas d) => '())
) ;let

(let ((d
        (make-definition "JSON"
          '("*.json")
          "Level0"
          (list (cons "Level0" (make-context-def "Level0")))
          (list (cons "Key" "Others"))
        ) ;make-definition
      ) ;d
     ) ;
  (check (definition-extensions d) => '("*.json"))
  (check (= (length (definition-contexts d)) 1) => #t)
  (check (= (length (definition-item-datas d)) 1) => #t)
) ;let

(check-report)
