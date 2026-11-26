;; make-context-def
;; 构造上下文定义对象。
;;
;; 语法
;; ----
;; (make-context-def name)
;; (make-context-def name attribute line-end-context fallthrough-context rules)
;;
;; 参数
;; ----
;; name : string
;; 上下文名称。
;;
;; attribute : string (可选)
;; 默认 itemData 名称，默认 "Normal"。
;;
;; line-end-context : list (可选)
;; 行尾切换指令，默认 '(stay)。
;;
;; fallthrough-context : list (可选)
;; 无规则匹配时的切换指令，默认 #f。
;;
;; rules : list (可选)
;; 规则列表，默认 '()。
;;
;; 返回值
;; ----
;; <context-def>
;; 上下文定义对象。

(import (scheme base)
  (liii check)
  (liii highlight rule)
  (liii highlight definition)
) ;import

(check-set-mode! 'report-failed)

(let ((c (make-context-def "Level0")))
  (check (context-def-name c) => "Level0")
  (check (context-def-attribute c) => "Normal")
  (check (context-def-line-end-context c) => '(stay))
  (check (context-def-fallthrough-context c) => #f)
  (check (context-def-rules c) => '())
) ;let

(let ((c
        (make-context-def "comment"
          "Comment"
          '(pop 1)
          #f
          (list (make-rule 'detect-identifier "Comment" '(stay) #f))
        ) ;make-context-def
      ) ;c
     ) ;
  (check (context-def-attribute c) => "Comment")
  (check (context-def-line-end-context c) => '(pop 1))
  (check (= (length (context-def-rules c)) 1) => #t)
) ;let

(check-report)
