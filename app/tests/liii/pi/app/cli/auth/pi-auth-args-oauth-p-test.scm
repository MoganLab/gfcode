;; pi-auth-args-oauth?
;; 读取 <pi-auth-args> 记录的 oauth? 字段，判断是否走 OAuth 登录路径。
;;
;; 语法
;; ----
;; (pi-auth-args-oauth? args) -> boolean?
;;
;; 参数
;; ----
;; args : <pi-auth-args>
;; auth 参数记录。
;;
;; 返回值
;; ------
;; boolean?
;; 为 #t 时表示用户以 --oauth 登录该 provider，走设备码流程而非 api_key。

(import (liii check) (liii pi app cli auth))

(check-set-mode! 'report-failed)

(check-true (pi-auth-args-oauth? (make-pi-auth-args :subcommand "login" :provider "kimi-coding" :oauth? #t)
            ) ;pi-auth-args-oauth?
) ;check-true

(check-true (not (pi-auth-args-oauth? (make-pi-auth-args :subcommand "login" :provider "kimi-coding" :key "sk-123")
                 ) ;pi-auth-args-oauth?
            ) ;not
) ;check-true

(check-true (not (pi-auth-args-oauth? (make-pi-auth-args #f "login" "deepseek" "sk-123")))
) ;check-true

(check-true (not (pi-auth-args-oauth? (make-pi-auth-args :help? #t))))

(check-report)
