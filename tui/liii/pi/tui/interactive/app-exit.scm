;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; /exit 交互：识别显式退出指令并请求主循环退出，与快捷键 Ctrl+D 共享
;; 统一的优雅退出生命周期（清空在途队列、退出备用屏、恢复终端状态）
(define-library (liii pi tui interactive app-exit)
  (export pi-app-exit-command? pi-app-submit-exit!)
  (import (scheme base) (liii string) (liii tui) (liii pi tui interactive state))
  (begin

    ;; /exit 为无参指令，不接受额外参数：仅严格匹配 "/exit"。
    ;; 带空格的 "/exit foo" 不按退出指令处理，避免误把后续文本当作参数吞掉。
    (define (pi-app-exit-command? text)
      (string=? text "/exit")
    ) ;define

    ;; 触发退出：清空输入框并置位退出标志，由主循环检测后复用与 Ctrl+D
    ;; 完全一致的退出清理路径，跳过消息入队与模型调用流程。
    (define (pi-app-submit-exit! app)
      (editor-set-text! (pi-app-editor app) "")
      (%pi-app-exit-requested-set! app #t)
    ) ;define

  ) ;begin
) ;define-library
