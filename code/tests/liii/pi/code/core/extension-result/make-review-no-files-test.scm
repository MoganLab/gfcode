;; make-review-no-files
;; 构造无可审查文件结果。
;;
;; 语法
;; ----
;; (make-review-no-files message notice)
;;
;; 参数
;; ----
;; message : string|#f  notice : string|#f
;;
;; 返回值
;; ----
;; review-no-files

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(let ((r (make-review-no-files "m" "n")))
  (check-true (review-no-files? r))
  (check (review-no-files-message r) => "m")
  (check (review-no-files-notice r) => "n")
) ;let

(check-report)
