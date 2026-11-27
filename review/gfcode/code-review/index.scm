;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode code-review index)
  (import (scheme base)
    (liii string)
    (liii pi code core extensions)
    (liii pi code cli args query)
    (gfcode code-review auto)
    (gfcode code-review interactive)
    (gfcode code-review modes)
  ) ;import
  (export extension)
  (begin

    (define (extension api . opt-context)
      (define tracker (make-pi-review-edit-tracker))
      ;; 1. 注册 flags
      (register-flag! api
        (make-extension-flag-def "--code-review" "Review diff" :key 'code-review)
      ) ;register-flag!
      (register-flag! api
        (make-extension-flag-def "--staged" "Review staged diff" :key 'staged)
      ) ;register-flag!
      (register-flag! api
        (make-extension-flag-def "--ref"
          "Review git ref"
          :key        'review-ref
          :takes-arg? #t
        ) ;make-extension-flag-def
      ) ;register-flag!

      ;; 2. 注册 commands
      (for-each (lambda (n)
                  (register-command! api
                    (make-extension-command-def n
                      "Run code review on changes"
                      pi-code-review-command
                      :params '()
                    ) ;make-extension-command-def
                  ) ;register-command!
                ) ;lambda
        '("/review" "review")
      ) ;for-each

      ;; 3. 注册 validator
      (register-validator! api
        (lambda (parsed . extra)
          (let ((code-review (pi-args-ref parsed 'code-review))
                (staged (pi-args-ref parsed 'staged))
                (ref (pi-args-ref parsed 'review-ref))
               ) ;
            (when (and staged (not code-review))
              (error 'pi-arg-error "--staged requires --code-review")
            ) ;when
            (when (and ref (not code-review))
              (error 'pi-arg-error "--ref requires --code-review")
            ) ;when
          ) ;let
        ) ;lambda
      ) ;register-validator!

      ;; 4. 注册 flow
      (register-flow! api
        (make-extension-flow-def 'code-review
          (lambda (p) (pi-args-ref p 'code-review))
          (lambda (parsed cfg mode initial-msg)
            ;; 独立审查全程抑制自动注入；结算（含异常）后恢复
            (dynamic-wind pi-code-review-injection-suppress!
              (lambda () (run-code-review-flow parsed cfg mode))
              pi-code-review-injection-restore!
            ) ;dynamic-wind
          ) ;lambda
          :local?   #f
          :priority 10
        ) ;make-extension-flow-def
      ) ;register-flow!

      ;; 5. 自动审查生命周期：tool_execution_end 只记成功编辑，
      ;; turn_end 固化快照，下一次 agent 请求前注入一次并清空
      (pi-on! api
        'tool_execution_end
        (lambda (payload) (pi-review-track-tool-result! tracker payload))
      ) ;pi-on!
      (pi-on! api
        'turn_end
        (lambda (payload)
          (let ((entry (and (pair? payload) (assq 'turn payload))))
            (if entry
              (pi-review-tracker-end-turn! tracker (cdr entry))
              (error 'pi-review-tracker "turn_end payload missing 'turn field" payload)
            ) ;if
          ) ;let
        ) ;lambda
      ) ;pi-on!

      ;; 6. 注册 prompt injector：自动审查默认启用（对齐 pi-code-review）；
      ;; 消费上一 turn 的编辑快照（一次性）；--code-review 独立审查期间
      ;; 由 interactive 模块置位抑制标志，避免历史快照重复注入
      (register-prompt-injector! api
        (lambda (tool-calls)
          (let* ((snapshot (and (pi-code-review-injection-enabled?)
                             (pi-review-tracker-take-edits! tracker)
                           ) ;and
                 ) ;snapshot
                 (entry (and snapshot (assq 'files snapshot)))
                 (files (and entry (cdr entry)))
                 (block (and files (pi-build-review-injection files)))
                ) ;
            (if block (string-trim-both block) #f)
          ) ;let*
        ) ;lambda
      ) ;register-prompt-injector!

      "code-review-loaded"
    ) ;define

  ) ;begin
) ;define-library
