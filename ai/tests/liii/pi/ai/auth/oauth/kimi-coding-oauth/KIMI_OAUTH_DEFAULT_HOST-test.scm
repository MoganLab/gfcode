;; KIMI_OAUTH_DEFAULT_HOST
;; Kimi Code OAuth 默认（国内）host 常量。
;;
;; 语法
;; ----
;; KIMI_OAUTH_DEFAULT_HOST -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 固定为 https://auth.kimi.com。

(import (liii check) (liii pi ai auth oauth kimi-coding-oauth))

(check-set-mode! 'report-failed)

(check KIMI_OAUTH_DEFAULT_HOST => "https://auth.kimi.com")

(check-report)
