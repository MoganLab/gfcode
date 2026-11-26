;; verbose-thinking-ping-due?
;; 判断是否到达思考进度提示阈值。
;;
;; 语法
;; ----
;; (verbose-thinking-ping-due? elapsed-ms)
;;
;; 参数
;; ----
;; elapsed-ms : number?
;; 距上次进度行的毫秒数。
;;
;; 返回值
;; ----
;; boolean?
;; 是否到达 60s 进度提示阈值。

(import (scheme base) (liii check) (liii pi code modes verbose thinking))

(check-set-mode! 'report-failed)

;; 1. verbose-thinking-ping-due? 阈值边界
(check (verbose-thinking-ping-due? 0) => #f)
(check (verbose-thinking-ping-due? 59999) => #f)
(check (verbose-thinking-ping-due? 60000) => #t)
(check (verbose-thinking-ping-due? 120000) => #t)

(check-report)
