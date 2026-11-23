;; pi-get-agent-dir
;; 返回 agent 目录（会话 sessions/、扩展 extensions/ 等非 JSON 配置的默认位置）。
;;
;; 语法
;; ----
;; (pi-get-agent-dir . opt-dir)
;;
;; 参数
;; ----
;; opt-dir : string?（可选）
;; 显式目录，优先级最高。
;;
;; 返回值
;; ------
;; path?
;; 绝对路径的 path 对象。按以下优先级确定目录：
;; 1. 显式参数 opt-dir
;; 2. 环境变量 PI_CODING_AGENT_DIR
;; 3. ~/.gf/agent（默认，不再回退 ~/.pi/agent）
;;
;; 注意
;; ----
;; agent 目录与 JSON 配置目录（gf-get-config-dir）默认均为 ~/.gf/agent，
;; 二者统一，不再兼容 node 版 pi 的 ~/.pi/agent。

(import (scheme base)
  (scheme process-context)
  (liii check)
  (liii string)
  (liii path)
  (liii os)
  (liii shutil)
  (liii pi code core tools read)
) ;import

(check-set-mode! 'report-failed)

(define (%normalize dir)
  (if (os-windows?)
    (string-replace (path->string dir) "\\" "/")
    (path->string (path-resolve dir))
  ) ;if
) ;define

;; 1. 是过程
(check-true (procedure? pi-get-agent-dir))

;; 2. 无任何覆盖时默认 ~/.gf/agent（不回退 ~/.pi/agent）
(let* ((home (path-join (path-temp-dir) "pi-get-agent-dir-home"))
       (saved-home (get-environment-variable "HOME"))
       (saved-profile (get-environment-variable "USERPROFILE"))
       (saved-pi (get-environment-variable "PI_CODING_AGENT_DIR"))
      ) ;
  (unsetenv "PI_CODING_AGENT_DIR")
  (path-mkdir (path-join home ".gf" "agent") :parents #t :exist-ok #t)
  (putenv "HOME" (path->string home))
  (when (os-windows?)
    (putenv "USERPROFILE" (path->string home))
  ) ;when
  (check (%normalize (pi-get-agent-dir))
    =>
    (string-append (%normalize (path-join home ".gf" "agent")))
  ) ;check
  ;; ~/.gf/agent 不存在时仍返回 ~/.gf/agent（不回退 ~/.pi/agent）
  (path-rmdir (path-join home ".gf" "agent"))
  (check (%normalize (pi-get-agent-dir))
    =>
    (string-append (%normalize (path-join home ".gf" "agent")))
  ) ;check
  (if saved-home (putenv "HOME" saved-home) (unsetenv "HOME"))
  (when (os-windows?)
    (if saved-profile (putenv "USERPROFILE" saved-profile) (unsetenv "USERPROFILE"))
  ) ;when
  (if saved-pi
    (putenv "PI_CODING_AGENT_DIR" saved-pi)
    (unsetenv "PI_CODING_AGENT_DIR")
  ) ;if
  (rmtree (path->string home) #t)
) ;let*

;; 3. PI_CODING_AGENT_DIR 环境变量覆盖
(let* ((saved (get-environment-variable "PI_CODING_AGENT_DIR"))
       (override (path->string (path-join (path-temp-dir) "pi-agent-dir-override")))
      ) ;
  (putenv "PI_CODING_AGENT_DIR" override)
  (check (%normalize (pi-get-agent-dir)) => (%normalize override))
  (if saved (putenv "PI_CODING_AGENT_DIR" saved) (unsetenv "PI_CODING_AGENT_DIR"))
) ;let*

;; 4. 显式目录参数优先于环境变量
(let* ((saved (get-environment-variable "PI_CODING_AGENT_DIR"))
       (override (path->string (path-join (path-temp-dir) "pi-agent-dir-override")))
       (explicit (path->string (path-join (path-temp-dir) "explicit-agent-dir")))
      ) ;
  (putenv "PI_CODING_AGENT_DIR" override)
  (check (%normalize (pi-get-agent-dir explicit)) => (%normalize explicit))
  (if saved (putenv "PI_CODING_AGENT_DIR" saved) (unsetenv "PI_CODING_AGENT_DIR"))
) ;let*

;; 5. 返回值是绝对路径对象
(check-true (path? (pi-get-agent-dir)))
(check-true (path-absolute? (pi-get-agent-dir)))

(check-report)
