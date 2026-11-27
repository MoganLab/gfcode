;; review-session-request-config
;; 取会话请求的 config。
;;
;; 语法
;; ----
;; (review-session-request-config r)
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
    (assoc 'y
      (review-session-request-config (make-review-session-request #f (list (cons 'y 2)) "p" #f #f #f '() '())
      ) ;review-session-request-config
    ) ;assoc
  ) ;cdr
  =>
  2
) ;check

(check-report)
