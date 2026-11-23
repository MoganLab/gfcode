;; pi-credential->json
;; 将 <pi-credential> record 转换为 Scheme-JSON 对象（alist）。
;;
;; 语法
;; ----
;; (pi-credential->json c) -> alist
;;
;; 参数
;; ----
;; c : pi-credential?
;; 服务商凭据 record。
;;
;; 返回值
;; ----
;; alist
;; 包含 provider、type 与 key 字段的 JSON 对象。

(import (scheme base) (liii check) (liii json) (liii pi ai config credential))

(check-set-mode! 'report-failed)

(check-true (procedure? pi-credential->json))

(let* ((c (pi-credential "google" "secret-key" "api_key"))
       (j (pi-credential->json c))
       (parsed (string->json (json->string j)))
      ) ;
  (check (cdr (assoc "provider" parsed)) => "google")
  (check (cdr (assoc "type" parsed)) => "api_key")
  (check (cdr (assoc "key" parsed)) => "secret-key")
) ;let*

(check-catch 'type-error (pi-credential->json '(("provider" . "openai"))))
(check-catch 'type-error (pi-credential->json "invalid"))

;; oauth 分支：输出 type/access/refresh/expires，region 有值才写
(let* ((c (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 #f))
       (j (pi-credential->json c))
       (parsed (string->json (json->string j)))
      ) ;
  (check (cdr (assoc "type" parsed)) => "oauth")
  (check (cdr (assoc "access" parsed)) => "acc")
  (check (cdr (assoc "refresh" parsed)) => "ref")
  (check (cdr (assoc "expires" parsed)) => 1893456000000)
  (check (assoc "region" parsed) => #f)
  (check (assoc "key" parsed) => #f)
) ;let*

;; oauth + region：region 落盘
(let* ((c (pi-credential "kimi-coding" #f "oauth" "acc" "ref" 1893456000000 "https://auth.kimi.ai"))
       (parsed (string->json (json->string (pi-credential->json c))))
      ) ;
  (check (cdr (assoc "region" parsed)) => "https://auth.kimi.ai")
) ;let*

(check-report)
