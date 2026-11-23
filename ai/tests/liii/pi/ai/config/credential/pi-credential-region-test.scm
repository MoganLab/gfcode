;; pi-credential-region
;; 获取 oauth 凭据登录时记录的 OAuth host 覆盖值（region）。
;;
;; 语法
;; ----
;; (pi-credential-region c) -> string? 或 #f
;;
;; 参数
;; ----
;; c : pi-credential?
;; 凭据 record 实例。
;;
;; 返回值
;; ----
;; string? 或 #f
;; 登录时的 host 覆盖值；默认 host 登录不写 region，返回 #f。

(import (liii check) (liii pi ai config credential))

(check-set-mode! 'report-failed)

(let ((c (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000
           "https://auth.kimi.ai")))
  (check (pi-credential-region c) => "https://auth.kimi.ai")
) ;let

(let ((c (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 #f)))
  (check (pi-credential-region c) => #f)
) ;let

(check-report)