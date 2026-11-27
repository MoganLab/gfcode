;; review-session-request-run-isolated
;; 取会话请求的 run-isolated 过程。
;;
;; 语法
;; ----
;; (review-session-request-run-isolated r)
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
  (procedure?
    (review-session-request-run-isolated (make-review-session-request #f #f "p" #f (lambda (thunk) (thunk)) #f '() '())
    ) ;review-session-request-run-isolated
  ) ;procedure?
) ;check-true

(check-report)
