;; pi-credential-oauth?
;; 判断凭据是否为 oauth 类型。
;;
;; 语法
;; ----
;; (pi-credential-oauth? obj) -> boolean?
;;
;; 参数
;; ----
;; obj : any
;; 任意对象。
;;
;; 返回值
;; ----
;; boolean?
;; 是 type 为 "oauth" 的 pi-credential 时返回 #t，否则 #f。

(import (liii check) (liii pi ai config credential))

(check-set-mode! 'report-failed)

(check-true (pi-credential-oauth? (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 #f)
            ) ;pi-credential-oauth?
) ;check-true
(check-false (pi-credential-oauth? (pi-credential "google" "k" "api_key")))
(check-false (pi-credential-oauth? (pi-credential "google" "k")))
(check-false (pi-credential-oauth? "oauth"))
(check-false (pi-credential-oauth? #f))

(check-report)
