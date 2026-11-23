;; pi-credential-expires
;; 获取 oauth 凭据 access token 的过期时刻（毫秒 epoch）。
;;
;; 语法
;; ----
;; (pi-credential-expires c) -> number? 或 #f
;;
;; 参数
;; ----
;; c : pi-credential?
;; 凭据 record 实例。
;;
;; 返回值
;; ----
;; number? 或 #f
;; 过期毫秒时间戳；api_key 凭据默认 #f。

(import (liii check) (liii pi ai config credential))

(check-set-mode! 'report-failed)

(let ((c (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 #f)))
  (check (pi-credential-expires c) => 1893456000000)
) ;let

(let ((c (pi-credential "google" "secret-key" "api_key")))
  (check (pi-credential-expires c) => #f)
) ;let

(check-report)
