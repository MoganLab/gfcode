;; pi-provider-oauth
;; 查询 provider 登记的订阅 OAuth 登录方式标识。
;;
;; 语法
;; ----
;; (pi-provider-oauth provider) -> string? 或 #f
;;
;; 参数
;; ----
;; provider : (or string? symbol?)
;; 服务商 id。
;;
;; 返回值
;; ----
;; string? 或 #f
;; kimi-coding 返回 "kimi-code"；未登记 OAuth 的 provider 返回 #f。

(import (liii check) (liii pi ai providers registry))

(check-set-mode! 'report-failed)

(check (pi-provider-oauth "kimi-coding") => "kimi-code")
(check (pi-provider-oauth 'kimi-coding) => "kimi-code")
(check (pi-provider-oauth "deepseek") => #f)
(check (pi-provider-oauth "google") => #f)
(check (pi-provider-oauth "no-such-provider") => #f)

(check-report)