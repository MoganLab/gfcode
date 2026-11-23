;; pi-oauth-store-load!
;; 用凭据列表整体重载 store：只保留 oauth 类型凭据，
;; 替换原有全部内容（/login 后 reload 场景）。
;;
;; 语法
;; ----
;; (pi-oauth-store-load! store credentials)
;;
;; 参数
;; ----
;; store : pi-oauth-store?
;; OAuth 运行时凭据 store。
;;
;; credentials : list?
;; 新凭据列表；非 oauth 凭据被过滤。
;;
;; 返回值
;; ----
;; pi-oauth-store?
;; 传入的 store（原地重载）。

(import (liii check)
  (liii pi ai config credential)
  (liii pi ai auth oauth store)
) ;import

(check-set-mode! 'report-failed)

(let* ((store (pi-make-oauth-store (list (pi-credential "old" #f "oauth" "acc-old" "ref" 1000 #f))
              ) ;pi-make-oauth-store
       ) ;store
       (loaded (pi-oauth-store-load! store
                 (list (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 4102444800000 #f)
                   (pi-credential "google" "sk-google")
                 ) ;list
               ) ;pi-oauth-store-load!
       ) ;loaded
      ) ;
  (check loaded => store)
  ;; 旧条目被整体替换，api_key 凭据被过滤。
  (check (pi-oauth-store-ref store "old") => #f)
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding")) => "acc")
  (check (pi-oauth-store-ref store "google") => #f)
) ;let*

;; 空列表清空 store。
(let ((store (pi-make-oauth-store (list (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1000 #f))
             ) ;pi-make-oauth-store
      ) ;store
     ) ;
  (pi-oauth-store-load! store '())
  (check (pi-oauth-store-ref store "kimi-coding") => #f)
) ;let

(check-report)
