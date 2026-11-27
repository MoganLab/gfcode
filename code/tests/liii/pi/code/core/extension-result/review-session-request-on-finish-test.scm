;; review-session-request-on-finish
;; 取会话请求的结算回调。
;;
;; 语法
;; ----
;; (review-session-request-on-finish r)
;;
;; 参数
;; ----
;; r : review-session-request
;;
;; 返回值
;; ----
;; procedure|#f

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check-true
  (procedure? (review-session-request-on-finish (make-review-session-request #f #f "p" (lambda _ #f) #f #f '() '())
              ) ;review-session-request-on-finish
  ) ;procedure?
) ;check-true

(check-report)
