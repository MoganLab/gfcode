;; review-session-request-notice
;; 取会话请求的 notice。
;;
;; 语法
;; ----
;; (review-session-request-notice r)
;;
;; 参数
;; ----
;; r : review-session-request
;;
;; 返回值
;; ----
;; string|#f

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-session-request-notice (make-review-session-request #f #f "p" #f #f "n" '() '())
       ) ;review-session-request-notice
  =>
  "n"
) ;check

(check-report)
