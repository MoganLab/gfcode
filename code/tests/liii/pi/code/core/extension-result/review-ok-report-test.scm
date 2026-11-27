;; review-ok-report
;; 取 review-ok 的报告文本。
;;
;; 语法
;; ----
;; (review-ok-report r)
;;
;; 参数
;; ----
;; r : review-ok
;;
;; 返回值
;; ----
;; string

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(check (review-ok-report (make-review-ok "rep")) => "rep")

(check-report)
