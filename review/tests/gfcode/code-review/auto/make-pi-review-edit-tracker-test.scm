;; make-pi-review-edit-tracker
;; 创建按 turn 聚合成功 write/edit 的自动审查追踪器。
;;
;; 语法
;; ----
;; (make-pi-review-edit-tracker)
;;
;; 参数
;; ----
;; 无参数。
;;
;; 返回值
;; ----
;; 返回新的 tracker；初始无累积编辑、无快照。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(let ((tracker (make-pi-review-edit-tracker)))
  (check (pi-review-tracker? tracker) => #t)
  (check (pi-review-tracker-take-edits! tracker) => #f)
) ;let

(check-report)
