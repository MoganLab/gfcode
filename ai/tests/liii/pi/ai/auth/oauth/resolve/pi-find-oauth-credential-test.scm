;; pi-find-oauth-credential
;; 在凭据列表中按 provider 精确匹配 oauth 凭据。
;;
;; 语法
;; ----
;; (pi-find-oauth-credential target auth-list) -> pi-credential? 或 #f
;;
;; 参数
;; ----
;; target : string? 或 #f
;; 服务商 id。
;;
;; auth-list : list?
;; pi-load-auth 返回的凭据列表。
;;
;; 返回值
;; ----
;; pi-credential? 或 #f
;; 匹配到的 oauth 凭据；api_key 条目不匹配。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth resolve)
) ;import

(check-set-mode! 'report-failed)

(define *oauth*
  (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 #f)
) ;define

(define *api-key* (pi-credential "kimi-coding" "sk-x" "api_key"))

(define *other* (pi-credential "deepseek" "sk-ds" "api_key"))

(check (pi-find-oauth-credential "kimi-coding" (list *other* *oauth*))
  =>
  *oauth*
) ;check
(check (pi-find-oauth-credential "kimi-coding" (list *api-key*)) => #f)
(check (pi-find-oauth-credential "deepseek" (list *other* *oauth*)) => #f)
(check (pi-find-oauth-credential "kimi-coding" '()) => #f)
(check (pi-find-oauth-credential #f (list *oauth*)) => #f)

(check-report)
