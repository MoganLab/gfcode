;; review-retry-prompt
;; 取 review-retry 的降级提示词。
;;
;; 语法
;; ----
;; (review-retry-prompt r)
;;
;; 参数
;; ----
;; r : review-retry
;;
;; 返回值
;; ----
;; string

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-retry-prompt (make-review-retry "p" (lambda _ #f))) => "p")

(check-report)
