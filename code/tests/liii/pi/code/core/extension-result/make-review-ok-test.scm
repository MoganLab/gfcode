;; make-review-ok
;; 构造审查成功报告结果。
;;
;; 语法
;; ----
;; (make-review-ok report)
;;
;; 参数
;; ----
;; report : string
;;
;; 返回值
;; ----
;; review-ok

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(let ((r (make-review-ok "report-text")))
  (check-true (review-ok? r))
  (check (review-ok-report r) => "report-text")
) ;let

(check-report)
