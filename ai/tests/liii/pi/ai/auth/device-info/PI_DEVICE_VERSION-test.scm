;; PI_DEVICE_VERSION
;; 设备信息头 X-Msh-Version 的客户端版本常量，与 gfproject.json package.version 同步。
;;
;; 语法
;; ----
;; PI_DEVICE_VERSION -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 非空版本号字符串，如 "2026.11.24"。

(import (scheme base)
  (liii check)
  (liii string)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

(check-true (string? PI_DEVICE_VERSION))
(check-true (not (string-null? PI_DEVICE_VERSION)))

(check-report)
