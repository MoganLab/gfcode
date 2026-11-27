;; review-no-files-notice
;; 取 review-no-files 的 notice。
;;
;; 语法
;; ----
;; (review-no-files-notice r)
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

(check (review-no-files-notice (make-review-no-files #f "notice")) => "notice")

(check-report)
