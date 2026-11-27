;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; CLI 执行流程：收集变更、构造只读审查参数、驱动会话并结算报告。
;; 含单次 fallback（结构化失败后用非结构化提示词重试一次）与
;; 终端/json/verbose 三种输出模式。从 modes.scm 拆出，原
;; (gfcode code-review modes) 入口仍重新导出 run-code-review-flow 以保持兼容。

(define-library (gfcode code-review flow)
  (import (scheme base)
    (scheme write)
    (liii base)
    (liii string)
    (liii pi code modes flow)
    (liii pi code modes output)
    (liii pi code modes verbose)
    (gfcode code-review request)
    (gfcode code-review response)
    (gfcode code-review prompt)
    (gfcode code-review result)
  ) ;import
  (export run-code-review-flow)
  (begin

    (define (%print-review-result res-msgs)
      (let ((result (pi-code-review-response res-msgs)))
        (if (review-error? result)
          (begin
            (display-stderr (review-error-message result))
            1
          ) ;begin
          (begin
            (display (review-ok-report result))
            (newline)
            0
          ) ;begin
        ) ;if
      ) ;let
    ) ;define

    (define (%run-fallback review-parsed rcfg request result)
      ;; 结构化审查失败后用非结构化提示词重试一次，仍失败才报错退出。
      (display-stderr (string-append "Structured review failed: "
                        (review-error-message result)
                        "; retrying with fallback prompt."
                      ) ;string-append
      ) ;display-stderr
      (%print-review-result (run-session-flow review-parsed
                              rcfg
                              (pi-build-fallback-prompt (review-session-request-records request))
                              #f
                              identity
                            ) ;run-session-flow
      ) ;%print-review-result
    ) ;define

    (define (%run-review-default review-parsed rcfg prompt mode request)
      ;; verbose 模式实时展示会话事件（含原始 JSON 输出）再结算；
      ;; 其余模式静默只出报告。结构化失败时降级为单次只读 fallback。
      (let* ((emit (if (eq? mode 'verbose) (make-verbose-emitter) #f))
             (result (run-session-flow review-parsed rcfg prompt emit pi-code-review-response)
             ) ;result
            ) ;
        (if (review-error? result)
          (%run-fallback review-parsed rcfg request result)
          (begin
            (display (review-ok-report result))
            (newline)
            0
          ) ;begin
        ) ;if
      ) ;let*
    ) ;define

    (define (run-code-review-flow parsed cfg mode)
      (let ((request (pi-prepare-code-review parsed cfg)))
        (if (review-no-files? request)
          (let ((msg "No changed files found. Specify file paths or make some changes first."))
            (if (eq? mode 'json) (display-stderr msg) (begin (display msg) (newline)))
            0
          ) ;let
          (let ((notice (review-session-request-notice request)))
            (when notice
              (display-stderr notice)
            ) ;when
            (let ((rcfg (pi-code-review-config cfg))
                  (review-parsed (pi-code-review-parsed parsed))
                  (prompt (review-session-request-prompt request))
                 ) ;
              (if (eq? mode 'json)
                (run-session-flow review-parsed rcfg prompt emit-json-event (lambda _ 0))
                (%run-review-default review-parsed rcfg prompt mode request)
              ) ;if
            ) ;let
          ) ;let
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
