;; pi-code-review-injection-suppress!
;; 独立审查期间置位抑制标志，使 injector 不消费历史编辑快照。
;;
;; 语法
;; ----
;; (pi-code-review-injection-suppress!)
;;
;; 参数
;; ----
;; 无参数。
;;
;; 返回值
;; ----
;; unspecified
;; 置位后 pi-code-review-injection-enabled? 为 #f；重复置位幂等。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(pi-code-review-injection-restore!)
(check (pi-code-review-injection-enabled?) => #t)
(pi-code-review-injection-suppress!)
(check (pi-code-review-injection-enabled?) => #f)
(pi-code-review-injection-suppress!)
(check (pi-code-review-injection-enabled?) => #f)
(pi-code-review-injection-restore!)

(check-report)
