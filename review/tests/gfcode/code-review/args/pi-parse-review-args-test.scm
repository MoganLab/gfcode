;; pi-parse-review-args
;; 解析交互式 code review 命令的参数。
;;
;; 语法
;; ----
;; (pi-parse-review-args text)
;;
;; 参数
;; ----
;; text : string?
;; `/review` 后面的原始参数文本。
;;
;; 返回值
;; ----
;; alist
;; 包含 files、ref、staged 和 error 字段。显式文件保持输入顺序。
;; 不抛出参数异常；未知选项或缺少 --ref 值时在 error 字段返回诊断文本。

(import (liii check) (gfcode code-review args))

(check-set-mode! 'report-failed)

(let ((opts (pi-parse-review-args "")))
  (check (cdr (assoc 'files opts)) => '())
  (check (cdr (assoc 'ref opts)) => "HEAD")
  (check (cdr (assoc 'staged opts)) => #f)
  (check (cdr (assoc 'error opts)) => #f)
) ;let

(let ((opts (pi-parse-review-args "--staged --ref=main src/a.ts src/b.py")))
  (check (cdr (assoc 'files opts)) => '("src/a.ts" "src/b.py"))
  (check (cdr (assoc 'ref opts)) => "main")
  (check (cdr (assoc 'staged opts)) => #t)
  (check (cdr (assoc 'error opts)) => #f)
) ;let

(let ((opts (pi-parse-review-args "--ref release.scm")))
  (check (cdr (assoc 'ref opts)) => "release.scm")
  (check (cdr (assoc 'files opts)) => '())
  (check (cdr (assoc 'error opts)) => #f)
) ;let

(check-true
  (string? (cdr (assoc 'error (pi-parse-review-args "--unknown"))))
) ;check-true
(check-true
  (string? (cdr (assoc 'error (pi-parse-review-args "--ref"))))
) ;check-true

(check-report)
