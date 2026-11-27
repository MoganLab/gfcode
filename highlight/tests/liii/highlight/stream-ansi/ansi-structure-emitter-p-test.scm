;; ansi-structure-emitter?
;; 判断对象是否为 ANSI 结构渲染适配器。
;;
;; 语法
;; ----
;; (ansi-structure-emitter? value)
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
  (liii highlight theme)
  (liii highlight stream-ansi)
) ;import

(check-set-mode! 'report-failed)

(let ((e (make-ansi-structure-emitter (make-definition "T")
           (default-breeze-dark-theme)
           (lambda (t) #f)
         ) ;make-ansi-structure-emitter
      ) ;e
     ) ;
  (check-true (ansi-structure-emitter? e))
  (check-false (ansi-structure-emitter? '()))
) ;let

(check-report)
