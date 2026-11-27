;; review-no-files-p
;; 判断对象是否为 review-no-files。
;;
;; 语法
;; ----
;; (review-no-files-p obj)
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

(check-true (review-no-files? (make-review-no-files #f #f)))
(check-false (review-no-files? (make-review-error "x")))

(check-report)
