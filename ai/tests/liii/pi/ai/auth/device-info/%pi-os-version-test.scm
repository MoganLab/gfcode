;; %pi-os-version
;; 系统版本：Windows 取 OS 环境变量，其余取 uname -sr，兜底 os-type。
;;
;; 语法
;; ----
;; (%pi-os-version env) -> string?
;;
;; 参数
;; ----
;; env : list? 或 #f
;; 环境变量 alist；#f 时读真实环境变量。
;;
;; 返回值
;; ----
;; string?
;; 非空系统版本字符串，仅含可打印 ASCII。

(import (scheme base)
  (liii check)
  (liii os)
  (liii string)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

;; Windows 读 OS 环境变量
(if (os-windows?)
  (check (%pi-os-version '(("OS" . "Windows_NT"))) => "Windows_NT")
  (check-true (string? (%pi-os-version '())))
) ;if

;; env 缺失时兜底非空
(check-true (string? (%pi-os-version '())))
(check-true (not (string-null? (%pi-os-version '()))))

(check-report)
