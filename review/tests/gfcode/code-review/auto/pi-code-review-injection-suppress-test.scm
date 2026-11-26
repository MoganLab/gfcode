;; 自动注入抑制标志
;; 独立审查期间置位后 injector 不消费快照；恢复后快照仍可消费。
;;
;; 语法
;; ----
;; (pi-code-review-injection-suppress!)
;; (pi-code-review-injection-restore!)
;; pi-code-review-injection-suppressed?
;;
;; 返回值
;; ----
;; suppress/restore 返回 unspecified；标志为 boolean。
;;
;; 错误行为
;; --------
;; 重复置位/恢复幂等。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

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
  ;; 恢复后同一快照仍可被消费一次
  (pi-code-review-injection-restore!)
  (check (pi-code-review-injection-enabled?) => #t)
  (check-true (let ((s (pi-review-tracker-take-edits! tracker))) (and s #t)))
  (check (pi-review-tracker-take-edits! tracker) => #f)
) ;let

(check-report)
