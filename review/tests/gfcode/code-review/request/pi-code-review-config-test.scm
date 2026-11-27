;; pi-code-review-config
;; 构造审查配置副本：保留启用的内置工具，并在执行层保护原工作区。
;;
;; 语法
;; ----
;; (pi-code-review-config cfg)
;;
;; 参数
;; ----
;; cfg : alist? | pi-config?
;; 当前会话配置。
;;
;; 返回值
;; ----
;; alist 配置或 pi-config 副本；不修改输入。保留已启用的 bash 等内置工具；
;; write/edit 仅可操作工作区外的路径。Windows 无法可靠解析链接，禁用这两个工具。
;; Bash 不受文件系统隔离，避免写入原工作区由审查提示词约束。

(import (scheme base)
  (liii check)
  (liii either)
  (liii os)
  (liii path)
  (liii subprocess)
  (liii tempfile)
  (liii pi agent tools)
  (liii pi ai message)
  (liii pi code config)
  (liii pi code core tools)
  (gfcode code-review request)
) ;import

(check-set-mode! 'report-failed)

(let* ((original '((tools "bash" "read" "custom") (provider . "google")))
       (result (pi-code-review-config original))
      ) ;
  (check (pi-cfg-ref result 'tools) => '("bash" "read"))
  (check (pi-cfg-ref result 'provider) => "google")
  (check (pi-cfg-ref original 'tools) => '("bash" "read" "custom"))
) ;let*

(let* ((original (make-pi-config :provider "google" :tools '("bash"
                                                             "edit"
                                                             "write")))
       (result (pi-code-review-config original))
      ) ;
  (check (pi-cfg-ref result 'tools)
    =>
    (if (os-windows?) '("bash") '("bash" "edit" "write"))
  ) ;check
  (check (pi-cfg-ref result 'provider) => "google")
  (check (pi-cfg-ref original 'tools) => '("bash" "edit" "write"))
) ;let*

(check
  (pi-cfg-ref (pi-code-review-config '((tools))) 'tools)
  =>
  '()
) ;check

(define (write-args file)
  (list (cons 'path file) (cons "content" "temporary text"))
) ;define

(define (edit-args file)
  (list (cons "path" file)
    (cons "edits" (vector '(("oldText" . "temporary") ("newText" . "verified"))))
  ) ;list
) ;define

(define (execute-through-agent cfg name args)
  (pi-execute-one-tool-call (pi-tool-call-block "call-1" name args) #f 5 cfg)
) ;define

(define (check-posix-links cfg copy protected-file workspace)
  ;; 已存在的链接与待创建文件的父目录都可能指向工作区。
  (let ((alias (path->string (path-join copy "alias")))
        (dangling (path->string (path-join copy "dangling")))
        (missing (path->string (path-join workspace "missing.txt")))
        (dir-link (path->string (path-join copy "workspace-link")))
       ) ;
    (check-true (either-right? (run-either (list "ln" "-s" protected-file alias))))
    (check-true (either-right? (run-either (list "ln" "-s" missing dangling))))
    (check-true (either-right? (run-either (list "ln" "-s" workspace dir-link))))
    (let ((execute (pi-cfg-ref cfg 'execute-tool-call)))
      (check-true (pi-tool-result-is-error (execute "write" (write-args alias))))
      (check-true (pi-tool-result-is-error (execute "write" (write-args dangling))))
      (check-true
        (pi-tool-result-is-error
          (execute "write" (write-args (path->string (path-join dir-link "missing.txt"))))
        ) ;pi-tool-result-is-error
      ) ;check-true
      (check-false (path-exists? missing))
    ) ;let
  ) ;let
) ;define

(define (check-bash-in-copy cfg copy)
  (let ((execute (pi-cfg-ref cfg 'execute-tool-call)))
    (unless (os-windows?)
      (check-false
        (pi-tool-result-is-error (execute "bash" '(("command"
                                                    . "printf verified > test-output.txt")) :cwd copy)
        ) ;pi-tool-result-is-error
      ) ;check-false
      (check (path-read-text (path-join copy "test-output.txt")) => "verified")
      (check-false (path-exists? (path "test-output.txt")))
    ) ;unless
  ) ;let
) ;define

(define (check-workspace-protection workspace copy)
  (let* ((workspace (path->string (path-resolve workspace)))
         (protected-file (path->string (path-join workspace "original.txt")))
         (copy-file (path->string (path-join copy "nested" "new.txt")))
         (missing (path-join workspace "missing.txt"))
         (cfg (pi-code-review-config (make-pi-config
                                       :tools '("bash" "edit" "write")
                                       :execute-tool-call execute-tool-call
                                     ) ;make-pi-config
              ) ;pi-code-review-config
         ) ;cfg
         (execute (pi-cfg-ref cfg 'execute-tool-call))
        ) ;
    (path-write-text protected-file "original temporary text")
    (check-true (pi-tool-result-message-is-error (execute-through-agent cfg "write" (write-args protected-file))
                ) ;pi-tool-result-message-is-error
    ) ;check-true
    (check-true (pi-tool-result-message-is-error (execute-through-agent cfg "edit" (edit-args protected-file))
                ) ;pi-tool-result-message-is-error
    ) ;check-true
    (check-true (pi-tool-result-is-error (execute "write" (write-args "./missing.txt")))
    ) ;check-true
    (check-true (pi-tool-result-is-error (execute "write" (write-args "../repo/missing.txt") :cwd copy)
                ) ;pi-tool-result-is-error
    ) ;check-true
    (check-true (pi-tool-result-is-error (execute "write" '())))
    (check-true (pi-tool-result-is-error (execute "read" (write-args protected-file)))
    ) ;check-true
    (check-bash-in-copy cfg copy)
    (unless (os-windows?)
      (check-false (pi-tool-result-is-error (execute "write" (write-args copy-file))))
      (check-false (pi-tool-result-is-error (execute "edit" (edit-args copy-file))))
      (check (path-read-text copy-file) => "verified text")
      (check-posix-links cfg copy protected-file workspace)
    ) ;unless
    (check (path-read-text protected-file) => "original temporary text")
    (check-false (path-exists? missing))
  ) ;let*
) ;define

(with-temp-dir
  (lambda (dir)
    (let ((before (getcwd))
          (workspace (path->string (path-join dir "repo")))
          (copy (path->string (path-join dir "repo-copy")))
         ) ;
      (mkdir workspace)
      (mkdir copy)
      (dynamic-wind (lambda () (chdir workspace))
        (lambda () (check-workspace-protection workspace copy))
        (lambda () (chdir before))
      ) ;dynamic-wind
    ) ;let
  ) ;lambda
  "pi-review-tools-"
) ;with-temp-dir

(check-report)
