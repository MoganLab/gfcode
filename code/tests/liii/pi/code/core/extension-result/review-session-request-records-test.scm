;; review-session-request-records
;; 取会话请求的文件记录列表。
;;
;; 语法
;; ----
;; (review-session-request-records r)
;;
;; 参数
;; ----
;; r : review-session-request
;;
;; 返回值
;; ----
;; list

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check
  (review-session-request-records
    (make-review-session-request #f
      #f
      "p"
      #f
      #f
      #f
      (list (list (cons 'path "a")))
      '()
    ) ;make-review-session-request
  ) ;review-session-request-records
  =>
  (list (list (cons 'path "a")))
) ;check

(check-report)
