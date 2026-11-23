;; pi-oauth-store?
;; 判断值是否为 OAuth 运行时凭据 store（单元素 vector）。
;;
;; 语法
;; ----
;; (pi-oauth-store? value)
;;
;; 参数
;; ----
;; value : any?
;; 任意值。
;;
;; 返回值
;; ----
;; boolean?
;; 单元素 vector（含 pi-make-oauth-store 的结果）为 #t，其余为 #f。

(import (liii check) (liii pi ai auth oauth store))

(check-set-mode! 'report-failed)

(check-true (pi-oauth-store? (pi-make-oauth-store)))
(check-true (pi-oauth-store? (vector '())))
(check-false (pi-oauth-store? (vector '() '())))
(check-false (pi-oauth-store? (vector)))
(check-false (pi-oauth-store? '()))
(check-false (pi-oauth-store? #f))
(check-false (pi-oauth-store? "store"))

(check-report)
