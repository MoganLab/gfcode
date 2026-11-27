;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 扩展命令执行结果的统一类型。
;; 用 define-record-type 取代 ad-hoc alist（以 'status 作 tag 的联合体），
;; 通过 record 谓词与不可变访问器消除 "对 #f 调 cdr" 一类崩溃，并使每个
;; 变体的合法字段在定义处显式声明。
;; 放在 code 域以同时被 app（worker）与 review（命令 handler）导入，
;; 避免跨域反向依赖。

(define-library (liii pi code core extension-result)
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
  (import (scheme base))
  (begin

    ;; 会话结算错误：模型请求失败、截断或占位返回值
    (define-record-type <review-error>
      (make-review-error message)
      review-error?
      (message review-error-message)
    ) ;define-record-type

    ;; 无可审查文件
    (define-record-type <review-no-files>
      (make-review-no-files message notice)
      review-no-files?
      (message review-no-files-message)
      (notice review-no-files-notice)
    ) ;define-record-type

    ;; 审查成功报告
    (define-record-type <review-ok>
      (make-review-ok report)
      review-ok?
      (report review-ok-report)
    ) ;define-record-type

    ;; 降级重试请求：结构化失败后用新 prompt/on-finish 再跑一次只读 session
    (define-record-type <review-retry>
      (make-review-retry prompt on-finish)
      review-retry?
      (prompt review-retry-prompt)
      (on-finish review-retry-on-finish)
    ) ;define-record-type

    ;; 会话执行请求：交给通用 worker 驱动一次只读 session
    (define-record-type <review-session-request>
      (make-review-session-request parsed config prompt on-finish run-isolated
        notice records paths
      ) ;make-review-session-request
      review-session-request?
      (parsed review-session-request-parsed)
      (config review-session-request-config)
      (prompt review-session-request-prompt)
      (on-finish review-session-request-on-finish)
      (run-isolated review-session-request-run-isolated)
      (notice review-session-request-notice)
      (records review-session-request-records)
      (paths review-session-request-paths)
    ) ;define-record-type

    ;; 统一谓词：是否为任一 review 结果变体
    (define (review-result? obj)
      (or (review-error? obj)
        (review-no-files? obj)
        (review-ok? obj)
        (review-retry? obj)
        (review-session-request? obj)
      ) ;or
    ) ;define

    ;; 取结果变体的 status tag（供仍需按 tag 分发的兼容处使用），
    ;; 返回符号：error / no-files / ok / retry / session-request
    (define (review-result-status r)
      (cond ((review-error? r) 'error)
            ((review-no-files? r) 'no-files)
            ((review-ok? r) 'ok)
            ((review-retry? r) 'retry)
            ((review-session-request? r) 'session-request)
            (else (error 'review-result "not a review-result" r))
      ) ;cond
    ) ;define

  ) ;begin
) ;define-library
