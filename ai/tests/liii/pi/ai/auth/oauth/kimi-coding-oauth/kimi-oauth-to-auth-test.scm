;; kimi-oauth->auth
;; oauth 凭据转请求头：Authorization: Bearer <access>。
;;
;; 语法
;; ----
;; (kimi-oauth->auth credential) -> alist
;;
;; 参数
;; ----
;; credential : pi-credential?
;; type 为 oauth 的凭据。
;;
;; 返回值
;; ----
;; alist
;; (("Authorization" . "Bearer <access>"))，与 pi toAuth() 等价。
;; 非 oauth 凭据抛 type-error。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth kimi-coding-oauth)
) ;import

(check-set-mode! 'report-failed)

(let ((c (pi-credential "kimi-coding" #f "oauth" "acc-tok" "ref" 1893456000000 #f)))
  (check (kimi-oauth->auth c) => '(("Authorization" . "Bearer acc-tok")))
) ;let

(check-catch 'type-error
  (kimi-oauth->auth (pi-credential "kimi-coding" "sk-api" "api_key"))
) ;check-catch
(check-catch 'type-error (kimi-oauth->auth "not-a-credential"))

(check-report)
