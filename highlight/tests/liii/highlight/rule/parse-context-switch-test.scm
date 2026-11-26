;; parse-context-switch
;; 解析 Kate 上下文切换字符串为结构化指令。
;;
;; 语法
;; ----
;; (parse-context-switch str)
;;
;; 参数
;; ----
;; str : string
;; 切换字符串，如 "#stay"、"#pop"、"#pop#pop!Target"、"Target"。
;;
;; 返回值
;; ----
;; list
;; '(stay)、'(push "Name")、'(pop N) 或 '(pop N "Target")。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

(check (parse-context-switch "#stay") => '(stay))
(check (parse-context-switch "") => '(stay))
(check (parse-context-switch "#pop") => '(pop 1))
(check (parse-context-switch "#pop#pop") => '(pop 2))
(check (parse-context-switch "#pop!comment") => '(pop 1 "comment"))
(check (parse-context-switch "#pop#pop!comment") => '(pop 2 "comment"))
(check (parse-context-switch "Level1") => '(push "Level1"))
(check (parse-context-switch "#pop(2)") => '(pop 2))
(check (parse-context-switch "#pop(2)!Target") => '(pop 2 "Target"))

(check-report)
