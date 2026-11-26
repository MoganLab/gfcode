;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 兼容入口：拆分到 request/response/flow 子模块后，原有 import 路径
;; (gfcode code-review modes) 与公开导出保持不变。
;; 请求准备实现已移至 request.scm，响应处理移至 response.scm，
;; CLI 执行流程移至 flow.scm。

(define-library (gfcode code-review modes)
  (import (gfcode code-review request)
    (gfcode code-review response)
    (gfcode code-review flow)
  ) ;import
  (export pi-prepare-code-review pi-code-review-parsed pi-code-review-config
    pi-code-review-response run-code-review-flow
  ) ;export
  (begin
  ) ;begin
) ;define-library
