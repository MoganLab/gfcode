;; make-status-card
;; 构造并返回扩展状态行组件（dim 提示，上方一空行间隔）。
;;
;; 语法
;; ----
;; (make-status-card msg)
;;
;; 参数
;; ----
;; msg : string
;; 状态提示文本。
;;
;; 返回值
;; ----
;; component?
;; 返回构造的实例。

(import (scheme base)
  (liii check)
  (liii string)
  (liii tui)
  (liii pi tui interactive views)
) ;import

(check-set-mode! 'report-failed)

;; 正常渲染：首行为空行间隔，第二行为 dim 提示
(let* ((card (make-status-card "TPS 38.5 tok/s")) (lines (component-render card 60)))
  (check (component? card) => #t)
  (check (length lines) => 2)
  (check (car lines) => "")
  (check-true (string-contains? (cadr lines) "TPS 38.5 tok/s"))
  (check (eq? lines (component-render card 60)) => #t)
) ;let*

;; 文本首尾空白被裁剪
(let ((lines (component-render (make-status-card "  hi  ") 40)))
  (check (cadr lines) => (string-append "\x1b;[2m" "hi" "\x1b;[0m"))
) ;let

;; 零宽不渲染任何行
(check (component-render (make-status-card "hi") 0) => '())
;; 空文本不渲染任何行
(check (component-render (make-status-card "   ") 40) => '())

(check-report)
