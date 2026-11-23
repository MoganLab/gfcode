;; pi-oauth-store-remove!
;; 从 store 中移除指定 provider 的凭据（invalid_grant / 登出场景）；
;; 其他 provider 的条目保持不变，provider 可为 symbol。
;;
;; 语法
;; ----
;; (pi-oauth-store-remove! store provider)
;;
;; 参数
;; ----
;; store : pi-oauth-store?
;; OAuth 运行时凭据 store。
;;
;; provider : (or string? symbol?)
;; 要移除的服务商标识。
;;
;; 返回值
;; ----
;; #f
;; 固定返回 #f；移除不存在的 provider 不报错。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth store)
) ;import

(check-set-mode! 'report-failed)

(let ((store (pi-make-oauth-store (list (pi-credential "kimi-coding" #f "oauth" "acc-k" "ref" 1000 #f)
                                    (pi-credential "google" #f "oauth" "acc-g" "ref" 2000 #f)
                                  ) ;list
             ) ;pi-make-oauth-store
      ) ;store
     ) ;
  (check (pi-oauth-store-remove! store "kimi-coding") => #f)
  (check (pi-oauth-store-ref store "kimi-coding") => #f)
  ;; 其他 provider 不受影响。
  (check (pi-credential-access (pi-oauth-store-ref store "google")) => "acc-g")
  ;; symbol provider 等价；移除不存在的 provider 幂等。
  (check (pi-oauth-store-remove! store 'google) => #f)
  (check (pi-oauth-store-remove! store 'google) => #f)
  (check (pi-oauth-store-ref store "google") => #f)
) ;let

(check-report)
