;; pi-get-session-agent-dir
;; 解析会话使用的 Pi Agent 根目录，不改变配置或扩展的路径。
;;
;; 语法
;; ----
;; (pi-get-session-agent-dir . opt-dir)
;;
;; 参数
;; ----
;; opt-dir : string?（可选），显式指定的 agent 目录。
;;
;; 返回值
;; ----
;; path?，存放 sessions/ 的绝对目录。
;; 非空显式目录优先于 PI_CODING_AGENT_DIR；均未提供时使用 ~/.pi/agent。

(import (scheme process-context)
  (liii check)
  (liii os)
  (liii path)
  (liii pi code core tools read)
) ;import
(check-set-mode! 'report-failed)

(let ((saved (get-environment-variable "PI_CODING_AGENT_DIR")))
  (putenv "PI_CODING_AGENT_DIR" "  ")
  (check (path->string (pi-get-session-agent-dir))
    =>
    (path->string (pi-abs-path "~/.pi/agent"))
  ) ;check
  (putenv "PI_CODING_AGENT_DIR" "./custom-pi")
  (check (path->string (pi-get-session-agent-dir ""))
    =>
    (path->string (pi-abs-path "./custom-pi"))
  ) ;check
  (check (path->string (pi-get-session-agent-dir "./explicit"))
    =>
    (path->string (pi-abs-path "./explicit"))
  ) ;check
  (if saved (putenv "PI_CODING_AGENT_DIR" saved) (unsetenv "PI_CODING_AGENT_DIR"))
) ;let

(check-report)
