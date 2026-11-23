;; pi-make-oauth-store
;; 创建 OAuth 运行时凭据 store：单元素 vector 保存凭据列表，
;; 可随不可变配置副本共享；替换条目而非修改凭据 record。
;;
;; 语法
;; ----
;; (pi-make-oauth-store)
;; (pi-make-oauth-store credentials)
;;
;; 参数
;; ----
;; credentials : list?
;; 可选，初始凭据列表（缺省为空表）。
;;
;; 返回值
;; ----
;; pi-oauth-store?
;; 新建 store；给定 credentials 时可按 provider 查到其中的 oauth 凭据。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth store)
) ;import

(check-set-mode! 'report-failed)

;; 无参：空 store。
(let ((store (pi-make-oauth-store)))
  (check-true (pi-oauth-store? store))
  (check (pi-oauth-store-ref store "kimi-coding") => #f)
) ;let

;; 传入初始凭据列表：可按 provider 查到。
(let* ((cred (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 4102444800000 #f))
       (store (pi-make-oauth-store (list cred)))
      ) ;
  (check-true (pi-oauth-store? store))
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding")) => "acc")
  (check (pi-oauth-store-ref store "google") => #f)
) ;let*

;; 每次调用返回独立 store，互不影响。
(let ((a (pi-make-oauth-store)) (b (pi-make-oauth-store)))
  (pi-oauth-store-set! a
    (pi-credential "kimi-coding" #f "oauth" "acc-a" "ref" 4102444800000 #f)
  ) ;pi-oauth-store-set!
  (check (pi-oauth-store-ref b "kimi-coding") => #f)
) ;let

(check-report)
