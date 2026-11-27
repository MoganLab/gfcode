;; pi-code-review-injection-enabled?
;; 读取时求值判断自动注入是否启用（供 injector 调用，避免按值绑定快照）。
;;
;; 语法
;; ----
;; (pi-code-review-injection-enabled?)
;;
;; 参数
;; ----
;; 无参数。
;;
;; 返回值
;; ----
;; boolean
;; 未抑制时 #t，抑制期间 #f；抑制期间不消费快照，恢复后快照仍可消费。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(pi-code-review-injection-restore!)
(check (pi-code-review-injection-enabled?) => #t)

(let ((tracker (make-pi-review-edit-tracker)))
  (pi-review-track-tool-result! tracker
    '((name . "write") (input ("path" . "a.scm")) (isError . #f))
  ) ;pi-review-track-tool-result!
  (pi-review-tracker-end-turn! tracker 0)
  ;; 抑制期间不消费：快照保留
  (pi-code-review-injection-suppress!)
  (check (pi-code-review-injection-enabled?) => #f)
  (check (and (pi-code-review-injection-enabled?)
           (pi-review-tracker-take-edits! tracker)
         ) ;and
    =>
    #f
  ) ;check
  (pi-code-review-injection-restore!)
  ;; 恢复后快照仍可消费
  (check (and (pi-code-review-injection-enabled?)
           (pair? (pi-review-tracker-take-edits! tracker))
         ) ;and
    =>
    #t
  ) ;check
) ;let

(check-report)
