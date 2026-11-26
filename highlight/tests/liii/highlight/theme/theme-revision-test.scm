;; theme-revision
;; 读取主题版本号。
;;
;; 语法
;; ----
;; (theme-revision th)
;;
;; 参数
;; ----
;; th : theme?
;; 主题对象。
;;
;; 返回值
;; ----
;; integer
;; 版本号。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check (theme-revision (make-theme)) => 1)
(check (theme-revision (make-theme "X" '() '() 42)) => 42)
(check (theme-revision (default-breeze-dark-theme)) => 1)

(check-report)
