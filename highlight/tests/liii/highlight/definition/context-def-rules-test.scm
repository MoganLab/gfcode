;; context-def-rules
;; 读取上下文定义的规则列表。
;;
;; 语法
;; ----
;; (context-def-rules c)
;;
;; 参数
;; ----
;; c : context-def?
;; 上下文定义对象。
;;
;; 返回值
;; ----
;; list
;; 规则对象列表。

(import (scheme base)
  (liii check)
  (liii highlight rule)
  (liii highlight definition)
) ;import

(check-set-mode! 'report-failed)

(check (context-def-rules (make-context-def "x")) => '())

(let ((rules (list (make-rule 'detect-spaces "Normal" '(stay) #t)
               (make-rule 'detect-char "Comment" '(stay) #\;)
             ) ;list
      ) ;rules
     ) ;
  (check
    (=
      (length (context-def-rules (make-context-def "x" "Normal" '(stay) #f rules)))
      2
    ) ;=
    =>
    #t
  ) ;check
) ;let

(check-report)
