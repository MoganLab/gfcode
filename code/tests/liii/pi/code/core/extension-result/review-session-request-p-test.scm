;; review-session-request-p
;; 判断对象是否为 review-session-request。
;;
;; 语法
;; ----
;; (review-session-request-p obj)
;;
;; 参数
;; ----
;; obj : any
;;
;; 返回值
;; ----
;; boolean

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check-true (review-session-request? (make-review-session-request #f #f "p" #f #f #f '() '())
            ) ;review-session-request?
) ;check-true
(check-false (review-session-request? (make-review-ok "r")))

(check-report)
