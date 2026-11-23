;; PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE
;; slow_down 后超时的错误消息常量（提示 WSL/VM 时钟漂移）。
;;
;; 语法
;; ----
;; PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 含 slow_down 与时钟同步提示的固定消息（对齐上游 pi）。

(import (liii check) (liii string) (liii pi ai auth oauth device-flow))

(check-set-mode! 'report-failed)

(check-true (string-contains? PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE "slow_down")
) ;check-true
(check-true (string-contains? PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE "clock"))

(check-report)
