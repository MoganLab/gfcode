;; pi-credential-refresh
;; 获取 oauth 凭据的 refresh token 字段。
;;
;; 语法
;; ----
;; (pi-credential-refresh c) -> string? 或 #f
;;
;; 参数
;; ----
;; c : pi-credential?
;; 凭据 record 实例。
;;
;; 返回值
;; ----
;; string? 或 #f
;; oauth 凭据的 refresh token；api_key 凭据默认 #f。

(import (liii check) (liii pi ai config credential))

(check-set-mode! 'report-failed)

(let ((c (pi-credential "kimi-coding" #f "oauth" "acc-token" "ref-token" 1893456000000 #f)))
  (check (pi-credential-refresh c) => "ref-token")
) ;let

(let ((c (pi-credential "google" "secret-key" "api_key")))
  (check (pi-credential-refresh c) => #f)
) ;let

(check-report)