;; run-goldpi
;; run-pi 的别名入口（与 gf goldpi / gf pi 行为一致）。
;;
;; 语法
;; ----
;; (run-goldpi raw-args) -> integer?
;;
;; 参数
;; ----
;; raw-args : list?
;; 原始命令行参数字符串列表。
;;
;; 返回值
;; ------
;; integer?
;; 进程退出码：成功为 0，错误为 1。

(import (liii check) (liii string) (liii pi app cli main))

(check-set-mode! 'report-failed)

;; run-goldpi 与 run-pi 行为一致：--help 输出帮助并返回 0
(let ((status #f))
  (let ((out
          (with-output-to-string
            (lambda () (set! status (run-goldpi '("gf" "pi" "--help"))))
          ) ;with-output-to-string
        ) ;out
       ) ;
    (check status => 0)
    (check-true (string-contains? out "Usage:"))
  ) ;let
) ;let

;; run-goldpi 与 run-pi 为同一过程
(check-true (eq? run-goldpi run-pi))

(check-report)
