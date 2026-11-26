;; theme-name
;; 读取主题名称。
;;
;; 语法
;; ----
;; (theme-name th)
;;
;; 参数
;; ----
;; th : theme?
;; 主题对象。
;;
;; 返回值
;; ----
;; string
;; 主题名称。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check (theme-name (make-theme)) => "Default")
(check (theme-name (make-theme "Solarized")) => "Solarized")
(check (theme-name (default-breeze-dark-theme)) => "Breeze Dark")

(check-report)
