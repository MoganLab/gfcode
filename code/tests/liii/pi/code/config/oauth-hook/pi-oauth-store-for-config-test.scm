;; pi-oauth-store-for-config
;; 取配置绑定的 oauth store；配置未携带 store 时从 auth.json 载入
;; oauth 凭据新建。切模复制配置共享同一 store，/login 后 reload 重建。
;;
;; 语法
;; ----
;; (pi-oauth-store-for-config cfg captured-env captured-dir)
;;
;; 参数
;; ----
;; cfg : (or pi-config? list?)
;; 请求配置；可携带 oauth-store 键。
;;
;; captured-env : list?
;; 环境变量 alist；空表时按无环境变量加载 auth.json。
;;
;; captured-dir : (or string? path?)
;; 配置目录（含 auth.json）。
;;
;; 返回值
;; ----
;; pi-oauth-store?
;; 配置已绑定则原样返回（保持身份）；否则新建并载入盘上 oauth 凭据。

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
  (path->string (path-join (path-temp-dir) "pi-oauth-store-for-config-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(define (write-auth! text)
  (path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
    text
  ) ;path-write-text
) ;define

(define CFG
  (make-pi-config :config-dir TMP-DIR :provider "kimi-coding")
) ;define

;; 1. 配置已绑定 store：原样返回，保持对象身份。
(let* ((bound (pi-make-oauth-store))
       (cfg (pi-cfg-set CFG 'oauth-store bound))
      ) ;
  (check (pi-oauth-store-for-config cfg '() TMP-DIR) => bound)
) ;let*

;; 2. 未绑定：从 auth.json 载入 oauth 凭据（api_key 被过滤）。
(write-auth!
  (string-append "{\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"acc\","
    "\"refresh\":\"ref\",\"expires\":"
    (number->string (+ (pi-current-time-millis) 3600000))
    "},\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"}}"
  ) ;string-append
) ;write-auth!
(let ((store (pi-oauth-store-for-config CFG '() TMP-DIR)))
  (check-true (pi-oauth-store? store))
  (check (pi-credential-access (pi-oauth-store-ref store "kimi-coding")) => "acc")
  (check (pi-oauth-store-ref store "google") => #f)
) ;let

;; 3. 无 auth.json：返回空 store，不抛异常。
(path-unlink (path (path-join TMP-DIR "auth.json")))
(let ((store (pi-oauth-store-for-config CFG '() TMP-DIR)))
  (check-true (pi-oauth-store? store))
  (check (pi-oauth-store-ref store "kimi-coding") => #f)
) ;let

(rmtree TMP-DIR)

(check-report)
