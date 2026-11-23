;; pi-oauth-store-ref
;; 按 provider 精确匹配 store 中的 oauth 凭据；provider 可为 symbol。
;; api_key 类型凭据即使同 provider 也不返回。
;;
;; 语法
;; ----
;; (pi-oauth-store-ref store provider)
;;
;; 参数
;; ----
;; store : pi-oauth-store?
;; OAuth 运行时凭据 store。
;;
;; provider : (or string? symbol?)
;; 服务商标识。
;;
;; 返回值
;; ----
;; (or pi-credential? #f)
;; 匹配的 oauth 凭据；不存在时返回 #f。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth store)
) ;import

(check-set-mode! 'report-failed)

(define KIMI-OAUTH
  (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 4102444800000 #f)
) ;define

(let ((store (pi-make-oauth-store (list KIMI-OAUTH (pi-credential "google" "sk-google")))
      ) ;store
     ) ;
  ;; string 与 symbol 两种 provider 写法等价。
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding")) => "acc")
  (check (pi-credential-access (pi-oauth-store-ref store 'kimi-coding)) => "acc")
  ;; api_key 凭据不匹配 oauth 查找。
  (check (pi-oauth-store-ref store "google") => #f)
  (check (pi-oauth-store-ref store "missing") => #f)
) ;let

(check (pi-oauth-store-ref (pi-make-oauth-store) "kimi-coding") => #f)

(check-report)
