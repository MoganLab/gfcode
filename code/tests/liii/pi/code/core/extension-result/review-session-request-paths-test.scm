;; review-session-request-paths
;; 取会话请求的路径列表。
;;
;; 语法
;; ----
;; (review-session-request-paths r)
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

(check (review-session-request-paths (make-review-session-request #f #f "p" #f #f #f '() (list "a" "b"))
       ) ;review-session-request-paths
  =>
  (list "a" "b")
) ;check

(check-report)
