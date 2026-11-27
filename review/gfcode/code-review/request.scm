;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 会话执行之前的准备逻辑：收集变更文件、构造审查参数并限制工具对原工作区的修改。

(define-library (gfcode code-review request)
  (import (scheme base)
    (scheme char)
    (liii list)
    (liii os)
    (liii path)
    (liii path stat)
    (liii string)
    (liii pi code cli args)
    (liii pi code cli args query)
    (liii pi code config)
    (liii pi code core tools)
    (liii pi code core tools read)
    (gfcode code-review files)
    (gfcode code-review prompt)
    (gfcode code-review result)
  ) ;import
  (export pi-prepare-code-review pi-code-review-parsed pi-code-review-config)
  (begin

    (define %review-system-prompt
      "You are a code reviewer operating inside pi. Inspect and verify the code, then report findings in the format requested. Do not modify the original workspace."
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
            (make-review-session-request #f
              #f
              (pi-build-review-prompt records)
              #f
              #f
              notice
              records
              paths
            ) ;make-review-session-request
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

    (define (%edit-tool? name)
      (or (equal? name "edit") (equal? name "write"))
    ) ;define

    (define (%workspace-path? target workspace)
      ;; 按路径段比较，避免把 repo-copy 当成 repo 的子目录。
      (catch 'value-error
        (lambda () (path-relative-to target workspace) #t)
        (lambda _ #f)
      ) ;catch
    ) ;define

    (define (%unresolved-link? target)
      ;; 非 strict 的 path-resolve 可能保留指向不存在目标的符号链接。
      ;; 检查第一个存在的路径，避免 write 沿悬空链接创建工作区文件。
      (let ((st
              (catch 'file-not-found-error
                (lambda () (path-stat (path->string target)))
                (lambda _ #f)
              ) ;catch
            ) ;st
           ) ;
        (if st
          (path-stat-symlink? st)
          (let ((parent (path-parent target)))
            (or (equal? (path->string parent) (path->string target))
              (%unresolved-link? parent)
            ) ;or
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    (define (%review-edit-target args opts workspace)
      (catch #t
        (lambda ()
          (let* ((raw (pi-arg-ref args "path"))
                 (cwd (pi-keyword-value :cwd opts (path->string (path-cwd))))
                 (target (and (string? raw)
                           (not (string-null? raw))
                           (not (string-index raw #\null))
                           (pi-resolve-path raw cwd)
                         ) ;and
                 ) ;target
                 ;; macOS 工作区可能忽略文件名大小写；保守拒绝同名路径。
                 (case-fold (if (equal? (os-type) "Darwin") string-foldcase (lambda (p) p)))
                ) ;
            (and target
              (path-absolute? target)
              (not (%workspace-path? (case-fold target) (case-fold workspace)))
              (not (%unresolved-link? (path target)))
              target
            ) ;and
          ) ;let*
        ) ;lambda
        (lambda _ #f)
      ) ;catch
    ) ;define

    (define (%replace-edit-path args target)
      (cons (cons "path" target)
        (filter
          (lambda (pair) (not (or (equal? (car pair) "path") (eq? (car pair) 'path))))
          args
        ) ;filter
      ) ;cons
    ) ;define

    (define (%execute-review-edit execute name args opts workspace)
      (let ((target (%review-edit-target args opts workspace)))
        (if target
          ;; 执行已检查的绝对路径，而不是让执行器重解原始相对路径。
          (apply execute name (%replace-edit-path args target) opts)
          (pi-tool-result "Code review cannot edit this path. Use a separate temporary copy outside the original workspace."
            #t
          ) ;pi-tool-result
        ) ;if
      ) ;let
    ) ;define

    (define (%review-executor execute tools workspace)
      (lambda (name args . opts)
        (cond ((not (member name tools))
               (pi-tool-result "Tool is not enabled for code review." #t)
              ) ;
              ((not (procedure? execute))
               (pi-tool-result "execute-tool-call not configured" #t)
              ) ;
              ((%edit-tool? name) (%execute-review-edit execute name args opts workspace))
              (else (apply execute name args opts))
        ) ;cond
      ) ;lambda
    ) ;define

    (define (pi-code-review-config cfg)
      (let* ((workspace (path->string (path-resolve (path-cwd) #t)))
             (active (or (pi-cfg-ref cfg 'tools) '()))
             (execute (pi-cfg-ref cfg 'execute-tool-call))
             ;; Windows 的 path-resolve 不解析链接，禁用 edit/write。
             ;; 只保留已启用的内置工具；扩展工具没有声明可供核验的副作用。
             (tools
               (filter
                 (lambda (name)
                   (and (member name PI_ALL_TOOL_NAMES)
                     (not (and (os-windows?) (%edit-tool? name)))
                   ) ;and
                 ) ;lambda
                 active
               ) ;filter
             ) ;tools
            ) ;
        (pi-cfg-merge cfg
          (list (cons 'tools tools)
            (cons 'execute-tool-call (%review-executor execute tools workspace))
          ) ;list
        ) ;pi-cfg-merge
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
