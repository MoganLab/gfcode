;; review-error-p
;; 判断对象是否为 review-error。
;;
;; 语法
;; ----
;; (review-error-p obj)
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

(check-true (review-error? (make-review-error "x")))
(check-false (review-error? (make-review-ok "r")))
(check-false (review-error? "nope"))

(check-report)
