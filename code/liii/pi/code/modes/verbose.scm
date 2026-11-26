;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 兼容入口：拆分到 verbose/ 子模块后，原有 import 路径
;; (liii pi code modes verbose) 与公开导出保持不变。
;; 公开函数实现已移至 events.scm 与 thinking.scm。

(define-library (liii pi code modes verbose)
  (import (liii pi code modes verbose events)
    (liii pi code modes verbose thinking)
  ) ;import
  (export display-agent-event display-verbose-event make-verbose-emitter
    handle-verbose-result verbose-thinking-ping-due?
  ) ;export
  (begin
  ) ;begin
) ;define-library
