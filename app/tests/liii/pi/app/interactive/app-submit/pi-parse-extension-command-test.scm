;; pi-parse-extension-command
;; 将交互输入解析为规范 slash command 名及原始参数。
;;
;; 语法
;; ----
;; (pi-parse-extension-command text)
;;
;; 参数
;; ----
;; text : string?
;; 已去除首尾空白的用户输入。
;;
;; 返回值
;; ----
;; pair | #f
;; slash command 返回 (name . args)，name 不含斜杠；其他输入返回 #f。
;; 不验证命令是否已注册，不解析引号，不抛出异常。

(import (liii check) (liii pi app interactive app-submit))

(check-set-mode! 'report-failed)

(check (pi-parse-extension-command "/review --staged src/a.ts")
  =>
  '("review" . "--staged src/a.ts")
) ;check
(check (pi-parse-extension-command "/review") => '("review" . ""))
(check (pi-parse-extension-command "hello") => #f)
(check (pi-parse-extension-command "/tmp/a.scm") => '("tmp/a.scm" . ""))

(check-report)
