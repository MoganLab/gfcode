;; make-review-retry
;; 构造降级重试请求结果。
;;
;; 语法
;; ----
;; (make-review-retry prompt on-finish)
;;
;; 参数
;; ----
;; prompt : string  ;; on-finish : procedure
;;
;; 返回值
;; ----
;; review-retry

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(let ((of (lambda (msgs) (make-review-ok "r"))))
  (let ((r (make-review-retry "p" of)))
    (check-true (review-retry? r))
    (check (review-retry-prompt r) => "p")
    (check-true (procedure? (review-retry-on-finish r)))
  ) ;let
) ;let

(check-report)
