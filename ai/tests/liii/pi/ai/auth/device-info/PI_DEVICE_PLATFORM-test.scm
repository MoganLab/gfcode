;; PI_DEVICE_PLATFORM
;; 设备信息头 X-Msh-Platform 的平台标识常量。
;;
;; 语法
;; ----
;; PI_DEVICE_PLATFORM -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 固定为 "gfcode"。

(import (scheme base)
  (liii check)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

(check PI_DEVICE_PLATFORM => "gfcode")

(check-report)
