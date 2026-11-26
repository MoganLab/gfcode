;; make-pi-review-edit-tracker
;; 创建按 turn 聚合成功 write/edit 的自动审查追踪器。
;;
;; 语法
;; ----
;; (make-pi-review-edit-tracker)
;; (pi-review-track-tool-result! tracker payload)
;; (pi-review-tracker-end-turn! tracker turn-index)
;; (pi-review-tracker-take-edits! tracker)
;;
;; 参数
;; ----
;; payload : alist?
;; 含 name、input、result、isError 的工具执行结束事件。
;; turn-index : integer?
;; 当前 turn 序号。
;;
;; 返回值
;; ----
;; make 返回 tracker；track/end-turn 返回 unspecified；
;; take-edits 返回含 files、turnIndex 的快照或 #f，并清空快照。
;;
;; 错误行为
;; --------
;; 忽略失败工具、非 write/edit、缺失路径；未知语言文件保留，language 为 #f。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(define (event name path failed)
  (list (cons 'name name)
    (cons 'input (list (cons "path" path)))
    (cons 'result "ok")
    (cons 'isError failed)
  ) ;list
) ;define

(let ((tracker (make-pi-review-edit-tracker)))
  (pi-review-track-tool-result! tracker (event "write" "a.scm" #f))
  (pi-review-track-tool-result! tracker (event "edit" "b.py" #f))
  (pi-review-track-tool-result! tracker (event "edit" "a.scm" #f))
  (pi-review-track-tool-result! tracker (event "write" "failed.ts" #t))
  (pi-review-track-tool-result! tracker (event "read" "read.ts" #f))
  (pi-review-track-tool-result! tracker (event "write" "unknown.xyz" #f))
  (pi-review-tracker-end-turn! tracker 7)
  (let ((snapshot (pi-review-tracker-take-edits! tracker)))
    (check (cdr (assoc 'turnIndex snapshot)) => 7)
    (check
      (map (lambda (f) (cdr (assoc 'path f))) (cdr (assoc 'files snapshot)))
      =>
      '("a.scm" "b.py" "unknown.xyz")
    ) ;check
  ) ;let
  (check (pi-review-tracker-take-edits! tracker) => #f)
  (pi-review-tracker-end-turn! tracker 8)
  (check (pi-review-tracker-take-edits! tracker) => #f)
) ;let

(check-report)
