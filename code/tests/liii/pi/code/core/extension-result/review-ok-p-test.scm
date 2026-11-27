;; review-ok-p
;; 判断对象是否为 review-ok。
;;
;; 语法
;; ----
;; (review-ok-p obj)
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

(check-true (review-ok? (make-review-ok "r")))
(check-false (review-ok? (make-review-error "x")))

(check-report)
