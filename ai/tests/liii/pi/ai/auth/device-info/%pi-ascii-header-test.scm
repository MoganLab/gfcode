;; %pi-ascii-header
;; Kimi 设备信息头的 ASCII 清洗（对齐 Kimi CLI asciiHeader）。
;;
;; 语法
;; ----
;; (%pi-ascii-header value [fallback]) -> string?
;;
;; 参数
;; ----
;; value : string? 或 #f
;; 原始 header 值；非字符串直接回退 fallback（默认 "unknown"）。
;;
;; 返回值
;; ----
;; string?
;; 仅含可打印 ASCII（0x20-0x7E）的非空字符串，两端 trim；空则回退。

(import (scheme base)
  (liii check)
  (liii os)
  (liii string)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

;; ASCII 清洗：保留可打印字符
(check (%pi-ascii-header "my-laptop") => "my-laptop")

;; 剔除控制字符与非 ASCII（中文主机名等）
(check (%pi-ascii-header "dev\x01;\x7f;box") => "devbox")
(check (%pi-ascii-header "张三的MacBook-Pro") => "MacBook-Pro")

;; 全被剔除或空白时回退
(check (%pi-ascii-header "张三") => "unknown")
(check (%pi-ascii-header "   ") => "unknown")
(check (%pi-ascii-header #f) => "unknown")
(check (%pi-ascii-header "" "fallback") => "fallback")

;; 结果 trim 两端空白
(check (%pi-ascii-header "  spaced  ") => "spaced")

(check-report)
