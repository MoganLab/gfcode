;; %pi-editor-top-border
;; 交互模式编辑器顶边框显示开关常量。
;;
;; 语法
;; ----
;; %pi-editor-top-border
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; boolean?
;; 默认开启状态返回 #t。

(import (scheme base)
  (liii check)
  (liii tui)
  (liii pi app interactive app)
  (liii pi app interactive state)
) ;import

(check-set-mode! 'report-failed)

(check %pi-editor-top-border => #t)

(check-report)
