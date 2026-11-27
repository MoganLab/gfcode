;; review-retry-p
;; 判断对象是否为 review-retry。
;;
;; 语法
;; ----
;; (review-retry-p obj)
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

(check-true (review-retry? (make-review-retry "p" (lambda _ #f))))
(check-false (review-retry? (make-review-ok "r")))

(check-report)
