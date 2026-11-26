;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode code-review interactive)
  (import (scheme base)
    (liii pi code cli args)
    (gfcode code-review auto)
    (gfcode code-review args)
    (gfcode code-review prompt)
    (gfcode code-review modes)
  ) ;import
  (export pi-code-review-command)
  (begin

    (define %no-files-message
      "No changed files found. Specify file paths or make some changes first."
    ) ;define

    (define* (pi-code-review-command args ctx (prepare pi-prepare-code-review))
      (let* ((options (pi-parse-review-args args))
             (error-message (cdr (assoc 'error options)))
             (config (cdr (or (assoc 'config ctx) '(#f))))
            ) ;
        (if error-message
          (list (cons 'status 'error) (cons 'message error-message))
          (let* ((parsed
                   (list (cons 'messages (cdr (assoc 'files options)))
                     (cons 'review-ref (cdr (assoc 'ref options)))
                     (cons 'staged (cdr (assoc 'staged options)))
                     (cons 'code-review #t)
                     (cons 'no-auto-compact #t)
                     (cons 'no-skills #t)
                   ) ;list
                 ) ;parsed
                 (request (prepare parsed config))
                ) ;
            (if (eq? (cdr (assoc 'status request)) 'no-files)
              (list (cons 'status 'no-files) (cons 'message %no-files-message))
              (append request
                (list (cons 'parsed (pi-code-review-parsed parsed))
                  (cons 'config (pi-code-review-config config))
                  ;; 直接结构化审查失败时降级为只读 fallback 提示词重试一次；
                  ;; fallback 也不可用（worker 无此字段）时回退原结果
                  (cons 'on-finish
                    (lambda (msgs)
                      (let ((result (pi-code-review-response msgs)))
                        (if (eq? (cdr (assoc 'status result)) 'error)
                          (let ((retry (cdr (or (assoc 'fallback-runner ctx) '(#f
                                                                               . #f)))))
                            (if (procedure? retry)
                              ;; 降级会话保持只读；提示词由 fallback 构造器生成，
                              ;; 结算仍用统一响应解析（不再重试）
                              (retry (pi-build-fallback-prompt (cdr (assoc 'records request)))
                                pi-code-review-response
                              ) ;retry
                              result
                            ) ;if
                          ) ;let
                          result
                        ) ;if
                      ) ;let
                    ) ;lambda
                  ) ;cons
                  ;; 独立审查会话在抑制窗口内执行：首轮 injector 不消费
                  ;; 历史编辑快照；dynamic-wind 保证异常/中止后也恢复
                  (cons 'run-isolated
                    (lambda (thunk)
                      (dynamic-wind pi-code-review-injection-suppress!
                        thunk
                        pi-code-review-injection-restore!
                      ) ;dynamic-wind
                    ) ;lambda
                  ) ;cons
                ) ;list
              ) ;append
            ) ;if
          ) ;let*
        ) ;if
      ) ;let*
    ) ;define*

  ) ;begin
) ;define-library
