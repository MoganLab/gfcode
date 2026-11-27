;; review-result-status
;; 取结果变体的 status tag 符号。
;;
;; 语法
;; ----
;; (review-result-status r)
;;
;; 参数
;; ----
;; r : review-result
;;
;; 返回值
;; ----
;; symbol

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-result-status (make-review-error "e")) => 'error)
(check (review-result-status (make-review-no-files #f #f)) => 'no-files)
(check (review-result-status (make-review-ok "r")) => 'ok)
(check (review-result-status (make-review-retry "p" (lambda _ #f))) => 'retry)
(check (review-result-status (make-review-session-request #f #f "p" #f #f #f '() '()))
  =>
  'session-request
) ;check

(check-report)
