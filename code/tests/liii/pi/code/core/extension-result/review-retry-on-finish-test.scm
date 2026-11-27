;; review-retry-on-finish
;; 取 review-retry 的结算回调。
;;
;; 语法
;; ----
;; (review-retry-on-finish r)
;;
;; 参数
;; ----
;; r : review-retry
;;
;; 返回值
;; ----
;; procedure

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check-true
  (procedure? (review-retry-on-finish (make-review-retry "p" (lambda _ #f))))
) ;check-true

(check-report)
