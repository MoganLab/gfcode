;; resolve-app-mode
;; 根据命令行参数与终端状态解析运行模式。
;;
;; 语法
;; ----
;; (resolve-app-mode mode-option print-flag stdin-tty stdout-tty :custom-flow? custom-flow?)
;;
;; 参数
;; ----
;; mode-option : (or string symbol #f)
;; 命令行指定的运行模式。
;;
;; print-flag : boolean
;; 是否使用 print 模式。
;;
;; stdin-tty : boolean
;; 标准输入是否为终端。
;;
;; stdout-tty : boolean
;; 标准输出是否为终端。
;;
;; custom-flow? : boolean（可选）
;; 是否匹配独立扩展 flow；匹配时默认使用非交互分发，显式 mode 优先。
;;
;; 返回值
;; ----
;; symbol
;; 解析出的运行模式。

(import (liii check) (liii pi code modes))

(check-set-mode! 'report-failed)

;; resolve-app-mode
;; 根据命令行参数、stdin 是否为终端、stdout 是否为终端解析运行模式。
(check (resolve-app-mode "json" #f #t #t) => 'json)
(check (resolve-app-mode 'json #f #t #t) => 'json)
(check (resolve-app-mode "verbose" #f #t #t) => 'verbose)
(check (resolve-app-mode 'verbose #f #t #t) => 'verbose)
(check (resolve-app-mode "text" #f #t #t) => 'print)
(check (resolve-app-mode 'text #f #t #t) => 'print)
(check (resolve-app-mode #f #t #t #t) => 'verbose)
(check (resolve-app-mode #f #f #f #t) => 'verbose)
(check (resolve-app-mode #f #f #t #f) => 'verbose)
(check (resolve-app-mode #f #f #t #t) => 'interactive)
;; 匹配独立扩展 flow 时优先非交互分发，避免 --code-review 只打开 TUI。
(check (resolve-app-mode #f #f #t #t #t) => 'print)
;; 显式输出模式仍优先于 flow 的默认非交互模式。
(check (resolve-app-mode "json" #f #t #t #t) => 'json)

(check-report)
