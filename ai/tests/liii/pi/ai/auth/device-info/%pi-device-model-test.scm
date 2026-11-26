;; %pi-device-model
;; 设备型号组装：<os-type> <os-arch>。
;;
;; 语法
;; ----
;; (%pi-device-model) -> string?
;;
;; 参数
;; ----
;; 无。
;;
;; 返回值
;; ----
;; string?
;; 如 "Windows x64" / "Darwin arm64" / "Linux x86_64"，仅含可打印 ASCII。

(import (scheme base)
  (liii check)
  (liii os)
  (liii string)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

(check (%pi-device-model) => (string-append (os-type) " " (os-arch)))

(check-report)
