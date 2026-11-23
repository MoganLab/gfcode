;; pi-auth-normalize-secret
;; 校验并归一化密钥类字段（key/access/refresh）：去空白非空字符串。
;;
;; 语法
;; ----
;; (pi-auth-normalize-secret who field value) -> string?
;;
;; 参数
;; ----
;; who : string?
;; 错误消息前缀。
;;
;; field : string?
;; 字段名（用于错误消息）。
;;
;; value : string?
;; 待归一化的密钥。
;;
;; 返回值
;; ----
;; string?
;; 去空白后的密钥；空白抛 value-error，非 string 抛 type-error。

(import (liii check) (liii pi ai auth storage))

(check-set-mode! 'report-failed)

(check (pi-auth-normalize-secret "test" "key" "sk-abc") => "sk-abc")
(check (pi-auth-normalize-secret "test" "access" "  tok  ") => "tok")
(check-catch 'value-error (pi-auth-normalize-secret "test" "key" " "))
(check-catch 'type-error (pi-auth-normalize-secret "test" "key" 42))

(check-report)
