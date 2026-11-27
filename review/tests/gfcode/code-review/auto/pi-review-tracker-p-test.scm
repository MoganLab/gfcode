;; pi-review-tracker?
;; 判断值是否为自动审查追踪器。
;;
;; 语法
;; ----
;; (pi-review-tracker? obj)
;;
;; 参数
;; ----
;; obj : any
;; 任意值。
;;
;; 返回值
;; ----
;; boolean
;; tracker 返回 #t，其余返回 #f。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(check (pi-review-tracker? (make-pi-review-edit-tracker)) => #t)
(check (pi-review-tracker? '()) => #f)
(check (pi-review-tracker? 42) => #f)

(check-report)
