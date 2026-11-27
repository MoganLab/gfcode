;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 会话执行之前的准备逻辑：收集变更文件、构造禁止工具调用的
;; 审查参数与配置。从 modes.scm 拆出，原 (gfcode code-review modes)
;; 入口仍重新导出这些函数以保持兼容。

(define-library (gfcode code-review request)
  (import (scheme base)
    (liii pi code cli args)
    (liii pi code cli args query)
    (liii pi code config)
    (gfcode code-review files)
    (gfcode code-review prompt)
    (gfcode code-review result)
  ) ;import
  (export pi-prepare-code-review pi-code-review-parsed pi-code-review-config)
  (begin

    (define %review-system-prompt
      "You are a code reviewer operating inside pi. You have no tools: do not call, request, or simulate tool calls. All file contents to review are provided in the user message. Return only the JSON findings object requested there."
    ) ;define

    (define* (pi-prepare-code-review parsed
               cfg
               (collector pi-collect-changed-files)
               (file-records pi-review-file-records)
             ) ;pi-prepare-code-review
      (let* ((file-args (pi-args-ref parsed 'messages))
             (explicit (and (pair? file-args) file-args))
             (collected (collector
                          :ref     (or (pi-args-ref parsed 'review-ref) "HEAD")
                          :staged  (pi-args-ref parsed 'staged)
                          :files   explicit
                          :timeout (pi-resolve-timeout parsed cfg)
                        ) ;collector
             ) ;collected
             (paths (cdr (assoc 'paths collected)))
             (notice (cdr (assoc 'message collected)))
            ) ;
        (if (null? paths)
          (make-review-no-files #f notice)
          (let ((records (file-records paths)))
            (make-review-session-request
              #f ; parsed 由调用方追加
              #f ; config 由调用方追加
              (pi-build-review-prompt records)
              #f ; on-finish 由调用方追加
              #f ; run-isolated 由调用方追加
              notice
              records
              paths)
          ) ;let
        ) ;if
      ) ;let*
    ) ;define*

    (define (pi-code-review-parsed parsed)
      (if (pi-args-ref parsed 'system-prompt)
        parsed
        (pi-args-set parsed 'system-prompt %review-system-prompt)
      ) ;if
    ) ;define

    (define (pi-code-review-config cfg)
      ;; CLI 实际传入 pi-config record；pi-cfg-set 同时兼容 record 与 alist，
      ;; 保留 provider、模型、认证等其余配置，只清空审查会话的工具列表。
      (pi-cfg-set cfg 'tools '())
    ) ;define

  ) ;begin
) ;define-library
