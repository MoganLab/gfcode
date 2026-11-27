;; review-result-p
;; 判断对象是否为任一 review 结果变体。
;;
;; 语法
;; ----
;; (review-result-p obj)
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

(check-true (review-result? (make-review-error "e")))
(check-true (review-result? (make-review-ok "r")))
(check-true (review-result? (make-review-no-files #f #f)))
(check-true (review-result? (make-review-retry "p" (lambda _ #f))))
(check-true (review-result? (make-review-session-request #f #f "p" #f #f #f '() '()))
) ;check-true
(check-false (review-result? "nope"))

(check-report)
