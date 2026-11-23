;; pi-oauth-store-clear!
;; 清空 store 中的全部凭据；store 身份不变，共享该 store 的
;; 配置副本随之看到空 store。
;;
;; 语法
;; ----
;; (pi-oauth-store-clear! store)
;;
;; 参数
;; ----
;; store : pi-oauth-store?
;; OAuth 运行时凭据 store。
;;
;; 返回值
;; ----
;; 未指定
;; 仅原地清空，不依赖返回值。

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
  (pi-oauth-store-clear! store)
  (check (pi-oauth-store-ref store "kimi-coding") => #f)
  (check (pi-oauth-store-ref store "google") => #f)
  ;; 清空后仍可正常写入。
  (pi-oauth-store-set! store
    (pi-credential "kimi-coding" #f "oauth" "acc-new" "ref" 4102444800000 #f)
  ) ;pi-oauth-store-set!
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding"))
    =>
    "acc-new"
  ) ;check
) ;let

;; 空 store 上清空幂等。
(let ((store (pi-make-oauth-store)))
  (pi-oauth-store-clear! store)
  (check-true (pi-oauth-store? store))
) ;let

(check-report)
