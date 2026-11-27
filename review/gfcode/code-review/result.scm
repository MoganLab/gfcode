;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 兼容入口：扩展命令结果类型实现已移至 code 域
;; (liii pi code core extension-result)，以便 app（worker）与 review
;; （命令 handler）共享同一类型而避免跨域反向依赖。此处仅重新导出。

(define-library (gfcode code-review result)
  (import (liii pi code core extension-result))
  (export make-review-error review-error? review-error-message
    make-review-no-files review-no-files? review-no-files-message
    review-no-files-notice make-review-ok review-ok? review-ok-report
    make-review-retry review-retry? review-retry-prompt review-retry-on-finish
    make-review-session-request review-session-request?
    review-session-request-parsed review-session-request-config
    review-session-request-prompt review-session-request-on-finish
    review-session-request-run-isolated review-session-request-notice
    review-session-request-records review-session-request-paths review-result?
    review-result-status
  ) ;export
  (begin
  ) ;begin
) ;define-library
