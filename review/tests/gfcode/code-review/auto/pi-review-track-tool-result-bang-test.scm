;; pi-review-track-tool-result!
;; 记录一次工具执行结束事件：只接受成功的 write/edit，路径取自执行参数。
;;
;; 语法
;; ----
;; (pi-review-track-tool-result! tracker payload)
;;
;; 参数
;; ----
;; tracker : pi-review-tracker?
;; 目标追踪器。
;; payload : alist?
;; 含 name、input、result、isError 的工具执行结束事件。
;;
;; 返回值
;; ----
;; unspecified
;; 累积本轮编辑文件；忽略失败工具、非 write/edit、缺失路径；
;; 未知语言文件保留，language 为 #f；同路径去重。

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
  (check
    (map (lambda (f) (cdr (assoc 'path f)))
      (cdr (assoc 'files (pi-review-tracker-take-edits! tracker)))
    ) ;map
    =>
    '("a.scm" "b.py" "unknown.xyz")
  ) ;check
) ;let

(check-report)
