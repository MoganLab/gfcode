;; pi-has-oauth-credential?
;; 探测凭据列表中是否存在某 provider 的 oauth 凭据。
;;
;; 语法
;; ----
;; (pi-has-oauth-credential? target auth-list) -> boolean?
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
;; boolean?
;; 存在匹配的 oauth 凭据返回 #t，否则 #f；api_key 条目不算。

(import (scheme base)
  (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth resolve)
) ;import

(check-set-mode! 'report-failed)

(define *oauth*
  (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 #f)
) ;define

(define *api-key* (pi-credential "kimi-coding" "sk-x" "api_key"))

(define *other* (pi-credential "deepseek" "sk-ds" "api_key"))

(check-true (pi-has-oauth-credential? "kimi-coding" (list *other* *oauth*)))
(check-true
  (not (pi-has-oauth-credential? "kimi-coding" (list *api-key*)))
) ;check-true
(check-true
  (not (pi-has-oauth-credential? "deepseek" (list *other* *oauth*)))
) ;check-true
(check-true (not (pi-has-oauth-credential? "kimi-coding" '())))
(check-true (not (pi-has-oauth-credential? #f (list *oauth*))))

(check-report)
