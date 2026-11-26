;; pi-thinking-border-color
;; pi-thinking-border-color 的相关操作与逻辑实现。
;;
;; 语法
;; ----
;; (pi-thinking-border-color ...)
;;
;; 参数
;; ----
;; 详见语法说明。
;;
;; 返回值
;; ----
;; any
;; 视具体调用结果而定。

(import (scheme base) (liii check) (liii pi app interactive thinking))

(check-set-mode! 'report-failed)

;; thinking 边框颜色映射（对齐上游 pi dark 主题实测 RGB）
(check (pi-thinking-border-color "off") => "\x1b;[38;2;108;118;123m")
(check (pi-thinking-border-color "minimal") => "\x1b;[38;2;104;128;141m")
(check (pi-thinking-border-color "low") => "\x1b;[38;2;84;137;164m")
(check (pi-thinking-border-color "medium") => "\x1b;[38;2;97;133;204m")
(check (pi-thinking-border-color "high") => "\x1b;[38;2;151;118;229m")
(check (pi-thinking-border-color "xhigh") => "\x1b;[38;2;222;84;193m")
(check (pi-thinking-border-color "max") => "\x1b;[38;2;254;84;98m")
(check (pi-thinking-border-color "bogus") => "\x1b;[38;2;108;118;123m")

(check-report)
