;; PI_DEVICE_FLOW_CANCEL_MESSAGE
;; 设备码轮询被取消时的错误消息常量。
;;
;; 语法
;; ----
;; PI_DEVICE_FLOW_CANCEL_MESSAGE -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 固定为 "Login cancelled"（对齐上游 pi）。

(import (liii check) (liii pi ai auth oauth device-flow))

(check-set-mode! 'report-failed)

(check PI_DEVICE_FLOW_CANCEL_MESSAGE => "Login cancelled")

(check-report)
