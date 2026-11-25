;; main
;; 程序入口：以 command-line 为参数调用 run-pi 并以结果退出。
;;
;; 语法
;; ----
;; (main)
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; 不返回：通过 (exit (run-pi (command-line))) 终止进程。
;;
;; 注意
;; ----
;; main 内部直接调用 exit 终止进程，无法在测试进程内安全调用
;; （exit 不会被 catch 兜住）。此处仅断言 main 为过程且已导出绑定，
;; 真正的退出码行为由 run-pi 的测试覆盖。

(import (liii check) (liii pi tui cli main))

(check-set-mode! 'report-failed)

;; main 必须是一个可调用的过程（已绑定导出）
(check-true (procedure? main))

(check-report)
