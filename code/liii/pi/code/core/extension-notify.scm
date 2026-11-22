;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License.
;;
;;
;; 扩展通知注入点（参考 ai/abort.scm 的会话级注入模式）：
;;
;; 扩展运行在无 UI 上下文的注册表监听器中，无法直接触达 TUI。本模块提供一个
;; 全局 notify 过程槽位：TUI 启动时 arm 一个能上屏的回调，扩展通过
;; pi-extension-notify 触达；非 TUI 环境（verbose / 一次性运行）槽位为 #f，
;; 扩展回退到 stderr 输出，与 pi 的 ctx.hasUI 守护语义一致。
;;
;; 线程安全说明：槽位仅在 TUI 启动/结束时设置，扩展监听器在 worker 线程
;; 触发；TUI 回调经 chan 投递回主线程渲染，避免跨线程直接改组件状态。

(define-library (liii pi code core extension-notify)
  (import (scheme base))
  (export pi-extension-notify-set! pi-extension-notify-reset!
    pi-extension-notify pi-extension-notify?)
  (begin

    ;; 当前 arm 的通知回调；#f 表示未 arm（安全默认：回退 stderr）
    (define *notify-fn* #f)

    (define (pi-extension-notify-set! fn)
      (if (or (not fn) (procedure? fn))
        (set! *notify-fn* fn)
        (set! *notify-fn* #f)
      ) ;if
    ) ;define

    (define (pi-extension-notify-reset!)
      (set! *notify-fn* #f)
    ) ;define

    (define (pi-extension-notify?)
      (procedure? *notify-fn*)
    ) ;define

    ;; 触发通知；已 arm 时回调返回回调结果，否则返回 #f（调用方回退 stderr）
    (define (pi-extension-notify message)
      (if (procedure? *notify-fn*)
        (*notify-fn* message)
        #f
      ) ;if
    ) ;define

  ) ;begin
) ;define-library
