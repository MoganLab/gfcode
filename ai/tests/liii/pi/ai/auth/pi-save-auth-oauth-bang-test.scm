;; pi-save-auth-oauth!
;; 向 auth.json 保存或增量更新服务商 OAuth 凭据（type=oauth）。
;;
;; 语法
;; ----
;; (pi-save-auth-oauth! provider access refresh expires region)
;; (pi-save-auth-oauth! provider access refresh expires region opt-config-dir)
;;
;; 参数
;; ----
;; provider : (or string? symbol?)
;; 服务商标识。
;;
;; access : string?
;; OAuth access token（非空）。
;;
;; refresh : string?
;; OAuth refresh token（非空）。
;;
;; expires : number?
;; access token 过期毫秒 epoch（正数）。
;;
;; region : string? 或 #f
;; 登录时的 OAuth host 覆盖值；#f 不写 region 字段。
;;
;; opt-config-dir : (or string? path?)
;; 可选，配置目录（默认 ~/.gf/agent）。
;;
;; 返回值
;; ----
;; string?
;; 写入的 auth.json 文件路径。

(import (liii check)
  (liii os)
  (liii path)
  (liii path stat)
  (liii json)
  (liii list)
  (liii tempfile)
  (liii pi ai config credential)
  (liii pi ai auth)
) ;import

(check-set-mode! 'report-failed)

;; 1. 参数校验
(check-catch 'type-error (pi-save-auth-oauth! 1 "a" "r" 1 #f))
(check-catch 'value-error (pi-save-auth-oauth! " " "a" "r" 1 #f))
(check-catch 'type-error (pi-save-auth-oauth! "kimi-coding" 1 "r" 1 #f))
(check-catch 'value-error (pi-save-auth-oauth! "kimi-coding" "a" " " 1 #f))
(check-catch 'value-error (pi-save-auth-oauth! "kimi-coding" "a" "r" 0 #f))
(check-catch 'value-error (pi-save-auth-oauth! "kimi-coding" "a" "r" -5 #f))
(check-catch 'type-error (pi-save-auth-oauth! "kimi-coding" "a" "r" "x" #f))
(check-catch 'type-error (pi-save-auth-oauth! "kimi-coding" "a" "r" 1 5))

;; 2. 新建 auth.json 写入 oauth 条目，可被 pi-load-auth 解析，并自动激活 provider
(let* ((tmp (make-temp-dir "gf-auth-oauth-" ""))
       (target (pi-save-auth-oauth! "kimi-coding" "acc-1" "ref-1" 1893456000000 #f tmp)
       ) ;target
       (creds (pi-load-auth tmp))
      ) ;
  (check-true (path-exists? (path target)))
  (check (length creds) => 1)
  (check-true (pi-credential-oauth? (car creds)))
  (check (pi-credential-provider (car creds)) => "kimi-coding")
  (check (pi-credential-access (car creds)) => "acc-1")
  (check (pi-credential-refresh (car creds)) => "ref-1")
  (check (pi-credential-expires (car creds)) => 1893456000000)
  (check (pi-credential-region (car creds)) => #f)
  ;; OAuth 登录与 API Key 登录一致，把 provider 合并进白名单供 /model 使用
  (let ((wl (string->json (path-read-text (path-join tmp "models" "providers.json")))))
    (check-true (and (member "kimi-coding" (vector->list wl)) #t))
  ) ;let
  ;; 文件内容：无 region 字段
  (let ((raw (string->json (path-read-text (path target)))))
    (check (assoc "region" (cdr (assoc "kimi-coding" raw))) => #f)
  ) ;let
  ;; 权限 0600（非 Windows）
  (unless (os-windows?)
    (check (logand (path-stat-mode (path-stat target)) 511) => 384)
  ) ;unless
  (path-unlink (path target))
  (path-unlink (path-join tmp "models" "providers.json"))
  (path-rmdir (path-join tmp "models"))
  (path-rmdir tmp)
) ;let*

;; 3. region 落盘 + 覆盖更新 + 不破坏其它服务商条目和白名单
(let* ((tmp (make-temp-dir "gf-auth-oauth-" ""))
       (_ (pi-save-auth-key "deepseek" "sk-ds" tmp))
       (target (pi-save-auth-oauth! 'kimi-coding
                 "acc-1"
                 "ref-1"
                 1893456000000
                 "https://auth.kimi.ai"
                 tmp
               ) ;pi-save-auth-oauth!
       ) ;target
      ) ;
  (check (length (pi-load-auth tmp)) => 2)
  (let ((wl (string->json (path-read-text (path-join tmp "models" "providers.json")))))
    (check-true (and (member "deepseek" (vector->list wl)) (member "kimi-coding" (vector->list wl)) #t))
  ) ;let
  (pi-save-auth-oauth! "kimi-coding" "acc-2" "ref-2" 1893456000001 #f tmp)
  (let* ((creds (pi-load-auth tmp))
         (kimi
           (find (lambda (c) (equal? (pi-credential-provider c) "kimi-coding")) creds)
         ) ;kimi
        ) ;
    (check (length creds) => 2)
    (check (pi-credential-access kimi) => "acc-2")
    (check (pi-credential-region kimi) => #f)
    (check (pi-resolve-provider-key "deepseek" creds '()) => "sk-ds")
  ) ;let*
  (let ((wl (string->json (path-read-text (path-join tmp "models" "providers.json")))))
    (check (length (filter (lambda (p) (equal? p "kimi-coding")) (vector->list wl))) => 1)
  ) ;let
  (path-unlink (path target))
  (path-unlink (path-join tmp "models" "providers.json"))
  (path-rmdir (path-join tmp "models"))
  (path-rmdir tmp)
) ;let*

(check-report)
