;; PI_DEVICE_FLOW_TIMEOUT_MESSAGE
;; 设备码轮询超时（无 slow_down）时的错误消息常量。
;;
;; 语法
;; ----
;; PI_DEVICE_FLOW_TIMEOUT_MESSAGE -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 固定为 "Device flow timed out"（对齐上游 pi）。

(import (liii check) (liii pi ai auth oauth device-flow))

(check-set-mode! 'report-failed)

(check PI_DEVICE_FLOW_TIMEOUT_MESSAGE => "Device flow timed out")

(check-report)
