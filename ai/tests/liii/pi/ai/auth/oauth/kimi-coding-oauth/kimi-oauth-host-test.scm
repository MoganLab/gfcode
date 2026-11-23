;; kimi-oauth-host
;; 解析 OAuth host：KIMI_CODE_OAUTH_HOST > KIMI_OAUTH_HOST > 默认国内 host。
;;
;; 语法
;; ----
;; (kimi-oauth-host)
;; (kimi-oauth-host opt-env)
;;
;; 参数
;; ----
;; opt-env : list?
;; 自定义环境变量关联表 ((name . value) ...)。
;;
;; 返回值
;; ----
;; string?
;; 去掉尾部斜杠的 host；无覆盖时为 https://auth.kimi.com。

(import (liii check) (liii pi ai auth oauth kimi-coding-oauth))

(check-set-mode! 'report-failed)

;; 显式空 env：默认国内 host
(check (kimi-oauth-host '()) => "https://auth.kimi.com")

;; KIMI_CODE_OAUTH_HOST 覆盖（含尾斜杠剥离）
(check (kimi-oauth-host '(("KIMI_CODE_OAUTH_HOST" . "https://auth.kimi.ai/")))
  =>
  "https://auth.kimi.ai"
) ;check

;; KIMI_OAUTH_HOST 兜底
(check (kimi-oauth-host '(("KIMI_OAUTH_HOST" . "https://auth.kimi.ai")))
  =>
  "https://auth.kimi.ai"
) ;check

;; 优先级：KIMI_CODE_OAUTH_HOST > KIMI_OAUTH_HOST
(check (kimi-oauth-host '(("KIMI_OAUTH_HOST" . "https://b.example")
                          ("KIMI_CODE_OAUTH_HOST" . "https://a.example"))
       ) ;kimi-oauth-host
  =>
  "https://a.example"
) ;check

;; 空白覆盖值视为未设置
(check (kimi-oauth-host '(("KIMI_CODE_OAUTH_HOST" . "  ")))
  =>
  "https://auth.kimi.com"
) ;check

;; 本地 stub host
(check (kimi-oauth-host '(("KIMI_CODE_OAUTH_HOST" . "http://127.0.0.1:8080")))
  =>
  "http://127.0.0.1:8080"
) ;check

(check-report)
