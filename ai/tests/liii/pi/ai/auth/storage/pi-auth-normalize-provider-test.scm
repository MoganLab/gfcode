;; pi-auth-normalize-provider
;; 校验并归一化 provider：string/symbol → 去空白非空字符串。
;;
;; 语法
;; ----
;; (pi-auth-normalize-provider who provider) -> string?
;;
;; 参数
;; ----
;; who : string?
;; 错误消息前缀（调用方函数名）。
;;
;; provider : (or string? symbol?)
;; 待归一化的 provider。
;;
;; 返回值
;; ----
;; string?
;; 去空白后的 provider；空白抛 value-error，非 string/symbol 抛 type-error。

(import (liii check) (liii pi ai auth storage))

(check-set-mode! 'report-failed)

(check (pi-auth-normalize-provider "test" "kimi-coding") => "kimi-coding")
(check (pi-auth-normalize-provider "test" 'kimi-coding) => "kimi-coding")
(check (pi-auth-normalize-provider "test" "  deepseek  ") => "deepseek")
(check-catch 'value-error (pi-auth-normalize-provider "test" "   "))
(check-catch 'type-error (pi-auth-normalize-provider "test" 123))
(check-catch 'type-error (pi-auth-normalize-provider "test" #f))

(check-report)
