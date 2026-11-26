;; pi-review-tracker-take-edits!
;; 读取并清空编辑快照：同一批编辑只注入一次。
;;
;; 语法
;; ----
;; (pi-review-tracker-take-edits! tracker)
;;
;; 参数
;; ----
;; tracker : pi-review-tracker?
;; 目标追踪器。
;;
;; 返回值
;; ----
;; alist | #f
;; 有快照时返回含 files、turnIndex 的 alist 并清空；无快照返回 #f。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(let ((tracker (make-pi-review-edit-tracker)))
  (pi-review-track-tool-result! tracker
    '((name . "edit") (input ("path" . "b.py")) (isError . #f))
  ) ;pi-review-track-tool-result!
  (pi-review-tracker-end-turn! tracker 3)
  (let ((snapshot (pi-review-tracker-take-edits! tracker)))
    (check (pair? snapshot) => #t)
    (check (cdr (assoc 'turnIndex snapshot)) => 3)
  ) ;let
  ;; 快照已被取走：再次读取为 #f
  (check (pi-review-tracker-take-edits! tracker) => #f)
) ;let

(check-report)
