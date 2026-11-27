;; structure-stream?
;; 判断对象是否为结构事件流。
;;
;; 语法
;; ----
;; (structure-stream? value)
;;
;; 参数
;; ----
;; value : any
;;
;; 返回值
;; -----
;; boolean

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(check-true
  (structure-stream? (make-structure-stream (make-definition "Tiny") (lambda (ev) #f))
  ) ;structure-stream?
) ;check-true
(check-false (structure-stream? '()))

(check-report)
