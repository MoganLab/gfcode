;; PI_DEFAULT_PROVIDER
;; 未显式选择供应商时使用的全局默认供应商。
;;
;; 语法
;; ----
;; PI_DEFAULT_PROVIDER
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; string
;; 全局默认供应商标识 "deepseek"。

(import (liii check) (liii pi ai models defaults))

(check-set-mode! 'report-failed)

(check PI_DEFAULT_PROVIDER => "deepseek")

(check-report)
