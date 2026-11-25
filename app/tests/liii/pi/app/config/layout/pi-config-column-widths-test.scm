;; pi-config-column-widths
;; 按终端宽度计算 ranger 风格三列的列宽。
;;
;; 语法
;; ----
;; (pi-config-column-widths width)
;;
;; 参数
;; ----
;; width : integer
;; 终端宽度。
;;
;; 返回值
;; ----
;; list
;; 三列宽度组成的整数列表，第三列宽度为 0 表示隐藏。

(import (scheme base) (liii check) (liii pi app config layout))

(check-set-mode! 'report-failed)

;; 1. 宽屏三等分（第一列 32，第二列 48，其余给预览）
(check (pi-config-column-widths 120) => '(32 48 40))

;; 2. 中等宽度：第三列变窄但保留（width - 80 >= 12 时为三列）
(check (pi-config-column-widths 92) => '(32 48 12))

;; 3. 窄屏：第三列宽度为 0（隐藏）
;;    80 列进入双列模式：providers 取 32，models 取剩余 48
(check (pi-config-column-widths 80) => '(32 48 0))
(check (pi-config-column-widths 56) => '(28 28 0))
(check (pi-config-column-widths 40) => '(20 20 0))

;; 4. 极窄终端：左列受 10 列下限与 width/2 收缩约束
(check (pi-config-column-widths 20) => '(10 10 0))

(check-report)
