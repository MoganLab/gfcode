;; pi-app-submit-exit!
;; 识别 /exit 命令并触发退出流程：清空输入框并置位退出标志，
;; 与快捷键 Ctrl+D 共享统一的退出钩子，不发送消息给模型。
;;
;; 语法
;; ----
;; (pi-app-submit-exit! app)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; 返回值
;; ------
;; unspecified
;; 返回值未指定。

(import (scheme base)
  (liii check)
  (liii string)
  (liii tui)
  (liii pi tui interactive app)
  (liii pi tui interactive state)
  (liii pi tui interactive app-exit)
) ;import

(check-set-mode! 'report-failed)

;; 1. 置位退出标志并清空输入框
(let* ((app (make-pi-app :terminal (make-virtual-terminal :width 80 :height 24)))
       (ed (pi-app-editor app))
      ) ;
  (check (pi-app-exit-requested? app) => #f)
  (editor-set-text! ed "/exit")
  (pi-app-submit-exit! app)
  (check (pi-app-exit-requested? app) => #t)
  (check (editor-text ed) => "")
) ;let*

;; 2. 重复置位仍保持退出标志
(let ((app (make-pi-app :terminal (make-virtual-terminal :width 80 :height 24))))
  (pi-app-submit-exit! app)
  (pi-app-submit-exit! app)
  (check (pi-app-exit-requested? app) => #t)
) ;let

(check-report)
