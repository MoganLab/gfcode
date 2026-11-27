;; make-review-error
;; 构造一个会话结算错误结果。
;;
;; 语法
;; ----
;; (make-review-error message)
;;
;; 参数
;; ----
;; message : string
;;
;; 返回值
;; ----
;; review-error

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(let ((r (make-review-error "boom")))
  (check-true (review-error? r))
  (check (review-error-message r) => "boom")
) ;let

(check-report)
