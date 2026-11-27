;; review-session-request-prompt
;; 取会话请求的 prompt。
;;
;; 语法
;; ----
;; (review-session-request-prompt r)
;;
;; 参数
;; ----
;; r : review-session-request
;;
;; 返回值
;; ----
;; string

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-session-request-prompt (make-review-session-request #f #f "p" #f #f #f '() '())
       ) ;review-session-request-prompt
  =>
  "p"
) ;check

(check-report)
