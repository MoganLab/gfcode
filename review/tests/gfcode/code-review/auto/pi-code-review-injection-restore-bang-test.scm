;; pi-code-review-injection-restore!
;; 独立审查结束后恢复自动注入标志。
;;
;; 语法
;; ----
;; (pi-code-review-injection-restore!)
;;
;; 参数
;; ----
;; 无参数。
;;
;; 返回值
;; ----
;; unspecified
;; 恢复后 pi-code-review-injection-enabled? 为 #t；重复恢复幂等。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(pi-code-review-injection-suppress!)
(check (pi-code-review-injection-enabled?) => #f)
(pi-code-review-injection-restore!)
(check (pi-code-review-injection-enabled?) => #t)
(pi-code-review-injection-restore!)
(check (pi-code-review-injection-enabled?) => #t)

(check-report)
