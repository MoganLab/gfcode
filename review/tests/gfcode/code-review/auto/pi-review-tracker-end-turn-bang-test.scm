;; pi-review-tracker-end-turn!
;; turn 结束：把本轮累积编辑固化为快照；无编辑时清空旧快照。
;;
;; 语法
;; ----
;; (pi-review-tracker-end-turn! tracker turn-index)
;;
;; 参数
;; ----
;; tracker : pi-review-tracker?
;; 目标追踪器。
;; turn-index : integer?
;; 当前 turn 序号。
;;
;; 返回值
;; ----
;; unspecified
;; 本轮有编辑则生成含 files、turnIndex 的快照；无编辑则快照为 #f；
;; 调用后清空本轮累积。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(let ((tracker (make-pi-review-edit-tracker)))
  (pi-review-track-tool-result! tracker
    '((name . "write") (input ("path" . "a.scm")) (isError . #f))
  ) ;pi-review-track-tool-result!
  (pi-review-tracker-end-turn! tracker 7)
  (let ((snapshot (pi-review-tracker-take-edits! tracker)))
    (check (cdr (assoc 'turnIndex snapshot)) => 7)
    (check
      (map (lambda (f) (cdr (assoc 'path f))) (cdr (assoc 'files snapshot)))
      =>
      '("a.scm")
    ) ;check
  ) ;let
  ;; 本轮无编辑：旧快照被清空
  (pi-review-tracker-end-turn! tracker 8)
  (check (pi-review-tracker-take-edits! tracker) => #f)
) ;let

(check-report)
