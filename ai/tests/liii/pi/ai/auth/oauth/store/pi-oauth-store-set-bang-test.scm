;; pi-oauth-store-set!
;; 替换 store 中同 provider 的凭据条目（不修改凭据 record 本身），
;; 其他 provider 的条目保持不变；共享同一 store 的配置副本可见更新。
;;
;; 语法
;; ----
;; (pi-oauth-store-set! store cred)
;;
;; 参数
;; ----
;; store : pi-oauth-store?
;; OAuth 运行时凭据 store。
;;
;; cred : pi-credential?
;; 新凭据；provider 相同的旧条目被替换。
;;
;; 返回值
;; ----
;; pi-credential?
;; 传入的 cred。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth store)
) ;import

(check-set-mode! 'report-failed)

(let* ((old (pi-credential "kimi-coding" #f "oauth" "acc-1" "ref-1" 1000 #f))
       (other (pi-credential "google" #f "oauth" "acc-g" "ref-g" 2000 #f))
       (store (pi-make-oauth-store (list old other)))
       (new (pi-credential "kimi-coding" #f "oauth" "acc-2" "ref-2" 3000 #f))
      ) ;
  (check (pi-oauth-store-set! store new) => new)
  ;; 同 provider 条目被替换，其余保留。
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding"))
    =>
    "acc-2"
  ) ;check
  (check (pi-credential-refresh (pi-oauth-store-ref store "kimi-coding"))
    =>
    "ref-2"
  ) ;check
  (check (pi-credential-access (pi-oauth-store-ref store "google")) => "acc-g")
  ;; 原凭据 record 未被修改（替换而非原地变更）。
  (check (pi-credential-access old) => "acc-1")
) ;let*

;; 空 store 上新增 provider。
(let ((store (pi-make-oauth-store)))
  (pi-oauth-store-set! store
    (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 4102444800000 #f)
  ) ;pi-oauth-store-set!
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding")) => "acc")
) ;let

(check-report)
