;; KIMI_OAUTH_CLIENT_ID
;; Kimi Code OAuth 应用的 client_id 常量。
;;
;; 语法
;; ----
;; KIMI_OAUTH_CLIENT_ID -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 与上游 pi kimi-coding.ts 一致的固定 UUID。

(import (liii check) (liii pi ai auth oauth kimi-coding-oauth))

(check-set-mode! 'report-failed)

(check KIMI_OAUTH_CLIENT_ID => "17e5f671-d194-4dfb-9706-5516cb48c098")

(check-report)
