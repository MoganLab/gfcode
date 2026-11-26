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
    (liii string)
    (liii pi code modes flow)
    (liii pi code modes output)
    (liii pi code modes verbose)
    (gfcode code-review request)
    (gfcode code-review response)
    (gfcode code-review prompt)
  ) ;import
  (export run-code-review-flow)
  (begin

    (define (%print-review-result res-msgs)
      (let ((result (pi-code-review-response res-msgs)))
        (if (eq? (cdr (assoc 'status result)) 'error)
          (begin
            (display-stderr (cdr (assoc 'message result)))
            1
          ) ;begin
          (begin
            (display (cdr (assoc 'report result)))
            (newline)
            0
          ) ;begin
        ) ;if
      ) ;let
    ) ;define

    (define (run-code-review-flow parsed cfg mode)
      (let ((request (pi-prepare-code-review parsed cfg)))
        (if (eq? (cdr (assoc 'status request)) 'no-files)
          (let ((msg "No changed files found. Specify file paths or make some changes first."))
            (if (eq? mode 'json) (display-stderr msg) (begin (display msg) (newline)))
            0
          ) ;let
          (let ((notice (cdr (assoc 'notice request))))
            (when notice
              (display-stderr notice)
            ) ;when
            (let ((rcfg (pi-code-review-config cfg))
                  (review-parsed (pi-code-review-parsed parsed))
                  (prompt (cdr (assoc 'prompt request)))
                 ) ;
              (if (eq? mode 'json)
                (run-session-flow review-parsed rcfg prompt emit-json-event (lambda _ 0))
                ;; 直接结构化审查失败（模型 error/aborted/输出截断）时，
                ;; 降级为只读 fallback 提示词重试一次；仍失败才报错退出。
                ;; verbose 模式下实时展示会话事件（含原始 JSON 输出），
                ;; 结算后再打印格式化报告；其余模式保持静默只出报告。
                (let* ((emit (if (eq? mode 'verbose) (make-verbose-emitter) #f))
                       (result (run-session-flow review-parsed rcfg prompt emit pi-code-review-response)
                       ) ;result
                      ) ;
                  (if (eq? (cdr (assoc 'status result)) 'error)
                    (begin
                      (display-stderr (string-append "Structured review failed: "
                                        (cdr (assoc 'message result))
                                        "; retrying with fallback prompt."
                                      ) ;string-append
                      ) ;display-stderr
                      (%print-review-result
                        (run-session-flow review-parsed
                          rcfg
                          (pi-build-fallback-prompt (cdr (assoc 'records request)))
                          #f
                          identity
                        ) ;run-session-flow
                      ) ;%print-review-result
                    ) ;begin
                    (begin
                      (display (cdr (assoc 'report result)))
                      (newline)
                      0
                    ) ;begin
                  ) ;if
                ) ;let*
              ) ;if
            ) ;let
          ) ;let
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
