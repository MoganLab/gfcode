;; pi-remove-auth-provider!
;; 清除 auth.json 中某服务商的凭据条目（oauth 刷新失败时调用）。
;;
;; 语法
;; ----
;; (pi-remove-auth-provider! provider)
;; (pi-remove-auth-provider! provider opt-config-dir)
;;
;; 参数
;; ----
;; provider : (or string? symbol?)
;; 服务商标识。
;;
;; opt-config-dir : (or string? path?)
;; 可选，配置目录（默认 ~/.gf/agent）。
;;
;; 返回值
;; ----
;; string?
;; auth.json 文件路径（文件不存在时不创建，直接返回路径）。

(import (liii check)
  (liii path)
  (liii list)
  (liii tempfile)
  (liii pi ai config credential)
  (liii pi ai auth)
) ;import

(check-set-mode! 'report-failed)

;; 1. 参数校验
(check-catch 'type-error (pi-remove-auth-provider! 1))
(check-catch 'value-error (pi-remove-auth-provider! "  "))

;; 2. 文件不存在：返回路径且不创建文件
(let* ((tmp (make-temp-dir "gf-auth-remove-" ""))
       (target (pi-remove-auth-provider! "kimi-coding" tmp))
      ) ;
  (check-true (string? target))
  (check-false (path-exists? (path target)))
  (path-rmdir tmp)
) ;let*

;; 3. 清除 oauth 条目，不破坏其它服务商
(let* ((tmp (make-temp-dir "gf-auth-remove-" ""))
       (_ (pi-save-auth-key "deepseek" "sk-ds" tmp))
       (_ (pi-save-auth-oauth! "kimi-coding" "acc" "ref" 1893456000000 #f tmp))
      ) ;
  (check (length (pi-load-auth tmp)) => 2)
  (pi-remove-auth-provider! 'kimi-coding tmp)
  (let ((creds (pi-load-auth tmp)))
    (check (length creds) => 1)
    (check (pi-credential-provider (car creds)) => "deepseek")
  ) ;let
  ;; 幂等：再次清除不报错
  (pi-remove-auth-provider! "kimi-coding" tmp)
  (check (length (pi-load-auth tmp)) => 1)
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

(check-report)
