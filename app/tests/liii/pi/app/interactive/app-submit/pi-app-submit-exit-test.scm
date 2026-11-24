;; pi-app-submit-exit
;; /exit 命令提交分发：识别为显式退出指令并触发退出流程，
;; 与快捷键 Ctrl+D 共享统一的退出钩子，不发送消息给模型。
;;
;; 语法
;; ----
;; (pi-app-submit! app "/exit")
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;; text : string
;; 用户输入 "/exit"。
;;
;; 返回值
;; ------
;; 未指定

(import (scheme base)
  (liii check)
  (liii string)
  (liii tui)
  (liii pi agent queue)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive run)
) ;import

(check-set-mode! 'report-failed)

;; 1. /exit 置位退出标志：不作为普通文本发送给 handler，并清空输入框
(let* ((vt (make-virtual-terminal :width 80 :height 24))
       (submitted #f)
       (app (make-pi-app :terminal vt :handler (lambda (a m) (set! submitted m))))
       (ed (pi-app-editor app))
      ) ;
  (check (pi-app-exit-requested? app) => #f)
  (pi-app-submit! app "/exit")
  ;; 退出标志已置位
  (check (pi-app-exit-requested? app) => #t)
  ;; 不得把 /exit 当作提示词发送给模型
  (check submitted => #f)
  ;; 输入框已清空
  (check (editor-text ed) => "")
) ;let*

;; 2. /exit 经主循环提交后退出 TUI（与 Ctrl+D 返回同样的 #t）
(let* ((vt (make-virtual-terminal :width 80 :height 24))
       (submitted #f)
       (app (make-pi-app :terminal vt :handler (lambda (a m) (set! submitted m))))
      ) ;
  ;; 键入 /exit 并回车提交
  (virtual-terminal-push-key! vt "/")
  (virtual-terminal-push-key! vt "e")
  (virtual-terminal-push-key! vt "x")
  (virtual-terminal-push-key! vt "i")
  (virtual-terminal-push-key! vt "t")
  (virtual-terminal-push-key! vt 'enter)
  (check (pi-app-run app) => #t)
  ;; 退出后退出标志保持置位，handler 从未收到任何消息
  (check (pi-app-exit-requested? app) => #t)
  (check submitted => #f)
) ;let*

;; 3. /exit 不影响 Ctrl+D 退出路径：空输入框按 Ctrl+D 仍正常退出（无回归）
(let* ((vt (make-virtual-terminal :width 80 :height 24))
       (app (make-pi-app :terminal vt :handler (lambda (a m) #t)))
      ) ;
  (virtual-terminal-push-key! vt 'ctrl-d)
  (check (pi-app-run app) => #t)
  ;; Ctrl+D 退出不置位 /exit 标志（两者相互独立）
  (check (pi-app-exit-requested? app) => #f)
) ;let*

;; 4. /exit 带尾部空格不按退出指令处理：作为普通文本提交给 handler
(let* ((vt (make-virtual-terminal :width 80 :height 24))
       (submitted #f)
       (app (make-pi-app :terminal vt :handler (lambda (a m) (set! submitted m))))
       (ed (pi-app-editor app))
      ) ;
  (pi-app-submit! app "/exit ")
  ;; /exit 为无参指令，带空格后不被识别为退出
  (check (pi-app-exit-requested? app) => #f)
  (check submitted => "/exit ")
  (check (editor-text ed) => "")
) ;let*

;; 5. 在斜杠命令菜单中按回车补全 /exit 后退出主循环
(let* ((vt (make-virtual-terminal :width 100 :height 40))
       (submitted #f)
       (app (make-pi-app :terminal vt :handler (lambda (a m) (set! submitted m))))
       (ed (pi-app-editor app))
      ) ;
  ;; 输入 /ex 触发菜单，下移选中 exit（菜单顺序：model/thinking/name/session/resume
  ;; 第 5 项为 resume，config 为第 6（需滚动），login 第 7，exit 第 8）
  (virtual-terminal-push-key! vt "/")
  (virtual-terminal-push-key! vt "e")
  (virtual-terminal-push-key! vt "x")
  (virtual-terminal-push-key! vt 'enter)
  (check (pi-app-run app) => #t)
  (check (pi-app-exit-requested? app) => #t)
  (check submitted => #f)
) ;let*

(check-report)
