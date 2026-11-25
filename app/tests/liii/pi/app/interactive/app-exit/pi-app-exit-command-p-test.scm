;; pi-app-exit-command?
;; 判断用户输入文本是否为 /exit 退出命令。
;;
;; 语法
;; ----
;; (pi-app-exit-command? text)
;;
;; 参数
;; ----
;; text : string?
;; 用户输入的命令文本。
;;
;; 返回值
;; ------
;; boolean?
;; 是否严格匹配 "/exit"。

(import (scheme base) (liii check) (liii pi app interactive app-exit))

(check-set-mode! 'report-failed)

;; 1. 严格匹配 "/exit"
(check-true (pi-app-exit-command? "/exit"))

;; 2. 带尾部空格不识别为退出指令（无参指令）
(check-false (pi-app-exit-command? "/exit "))
(check-false (pi-app-exit-command? "/exit foo"))

;; 3. 非退出命令不匹配
(check-false (pi-app-exit-command? "/ex"))
(check-false (pi-app-exit-command? "/login"))
(check-false (pi-app-exit-command? "exit"))
(check-false (pi-app-exit-command? ""))

(check-report)
