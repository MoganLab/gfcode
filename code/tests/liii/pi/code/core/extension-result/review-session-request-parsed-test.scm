;; review-session-request-parsed
;; 取会话请求的 parsed 参数。
;;
;; 语法
;; ----
;; (review-session-request-parsed r)
;;
;; 参数
;; ----
;; r : review-session-request
;;
;; 返回值
;; ----
;; alist

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check
  (cdr
    (assoc 'x
      (review-session-request-parsed (make-review-session-request (list (cons 'x 1)) #f "p" #f #f #f '() '())
      ) ;review-session-request-parsed
    ) ;assoc
  ) ;cdr
  =>
  1
) ;check

(check-report)
