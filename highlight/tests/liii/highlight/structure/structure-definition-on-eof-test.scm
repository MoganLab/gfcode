;; structure-definition-on-eof
;; 获取 EOF 处理策略。
;;
;; 语法
;; ----
;; (structure-definition-on-eof definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; symbol：close、emit-unclosed 或 error-and-emit。

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-definition-on-eof (make-structure-definition "h" 'heading 'line "open")
       ) ;structure-definition-on-eof
  =>
  'close
) ;check
(check (structure-definition-on-eof (make-structure-definition "list" 'list 'nested "open" "close")
       ) ;structure-definition-on-eof
  =>
  'emit-unclosed
) ;check
(let ((object (make-structure-definition "object"
                'object
                'nested
                "open"
                "close"
                '()
                '()
                #t
                #t
                'error-and-emit
              ) ;make-structure-definition
      ) ;object
     ) ;
  (check (structure-definition-on-eof object) => 'error-and-emit)
) ;let

(check-report)
