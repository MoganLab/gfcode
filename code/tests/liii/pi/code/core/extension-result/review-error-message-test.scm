;; review-error-message
;; 取 review-error 的错误描述。
;;
;; 语法
;; ----
;; (review-error-message r)
;;
;; 参数
;; ----
;; r : review-error
;;
;; 返回值
;; ----
;; string

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-error-message (make-review-error "msg")) => "msg")

(check-report)
