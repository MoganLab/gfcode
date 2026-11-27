;; review-no-files-message
;; 取 review-no-files 的提示消息。
;;
;; 语法
;; ----
;; (review-no-files-message r)
;;
;; 参数
;; ----
;; r : review-no-files
;;
;; 返回值
;; ----
;; string|#f

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-no-files-message (make-review-no-files "m" #f)) => "m")

(check-report)
