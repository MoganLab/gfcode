;; pi-make-request-oauth-key-hook
;; 构造每次请求前解析 key 的钩子：未过期直接返回 store 中的 access，
;; 不联网、不写盘；无 oauth 凭据返回 #f。（过期透明刷新与 401 强制刷新
;; 的端到端行为分别见 pi-make-refresh-oauth-hook-test 与
;; pi-request-provider-oauth-refresh-test。）
;;
;; 语法
;; ----
;; (pi-make-request-oauth-key-hook captured-env captured-dir)
;;
;; 参数
;; ----
;; captured-env : list?
;; 环境变量 alist（可为空表）。
;;
;; captured-dir : (or string? path?)
;; 配置目录（含 auth.json）。
;;
;; 返回值
;; ----
;; procedure?
;; (lambda (cfg) ...)：未过期返回 access token（string?）；
;; 配置 provider 无 oauth 凭据时返回 #f。

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii pi ai config runtime)
  (liii pi ai config credential)
  (liii pi ai auth oauth store)
  (liii pi ai time)
  (liii pi code config oauth-hook)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-make-request-oauth-key-hook-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(define CFG (make-pi-config :config-dir TMP-DIR :provider "kimi-coding"))

(define HOOK (pi-make-request-oauth-key-hook '() TMP-DIR))

(check-true (procedure? HOOK))

;; 1. store 中凭据未过期：直接返回 access，auth.json 不被修改。
(let* ((cred (pi-credential "kimi-coding"
               #f
               "oauth"
               "fresh-acc"
               "ref"
               (+ (pi-current-time-millis) 3600000)
               #f
             ) ;pi-credential
       ) ;cred
       (cfg (pi-cfg-set CFG 'oauth-store (pi-make-oauth-store (list cred))))
      ) ;
  (check (HOOK cfg) => "fresh-acc")
  (check-false
    (file-exists? (path->string (path-join (path TMP-DIR) (path "auth.json"))))
  ) ;check-false
) ;let*

;; 2. 配置 provider 无 oauth 凭据：返回 #f。
(check (HOOK (pi-cfg-set CFG 'oauth-store (pi-make-oauth-store))) => #f)

;; 3. provider 缺失：返回 #f。
(check (HOOK (pi-cfg-set (pi-cfg-set CFG 'provider #f) 'oauth-store (pi-make-oauth-store))
       ) ;HOOK
  =>
  #f
) ;check

;; 4. 未绑定 store 时从 auth.json 初始化并返回未过期 access。
(path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
  (string-append "{\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"disk-acc\","
    "\"refresh\":\"ref\",\"expires\":"
    (number->string (+ (pi-current-time-millis) 3600000))
    "}}"
  ) ;string-append
) ;path-write-text
(check (HOOK CFG) => "disk-acc")

(rmtree TMP-DIR)

(check-report)
