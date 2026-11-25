;; pi-discover-extensions
;; 发现内置、用户级 ~/.gf/gfcode 与项目级 .gf/gfcode 的 library 扩展。
;;
;; 语法
;; ----
;; (pi-discover-extensions . options)
;;
;; 参数
;; ----
;; options : 关键字参数（:builtin-dir / :cwd / :include-builtin?）
;;
;; 返回值
;; ----
;; list
;; 同名仲裁后的 library 扩展描述符列表。

(import (scheme base)
  (scheme process-context)
  (liii check)
  (liii list)
  (liii string)
  (liii path)
  (liii os)
  (liii shutil)
  (liii pi code core extensions discovery)
) ;import

(check-set-mode! 'report-failed)

(define %FIX (path->string (path-resolve "code/tests/fixtures")))

(define (%entry-name entry)
  (cdr (assq 'name entry))
) ;define

(define (%probe-source name)
  (string-append "(define-library (gfcode " name ")\n"
    "  (import (scheme base)) (export extension)\n"
    "  (begin (define (extension api) \"" name "\"))))\n"
  ) ;string-append
) ;define

;; 1. 项目级 .gf/gfcode 扩展被发现。
(let* ((root (path-join (path-temp-dir) "pi-discover-library-project"))
       (dir (path-join root ".gf" "gfcode"))
       (file (path-join dir "proj-ext.scm"))
      ) ;
  (path-mkdir dir :parents #t :exist-ok #t)
  (path-write-text file (%probe-source "proj-ext"))
  (let ((result (pi-discover-extensions :cwd (path->string root) :builtin-dir %FIX)))
    (check-true
      (and
        (find (lambda (entry) (equal? (%entry-name entry) '(gfcode proj-ext))) result)
        #t
      ) ;and
    ) ;check-true
  ) ;let
  (rmtree (path->string root) #t)
) ;let*

;; 2. 项目级同名扩展覆盖用户级扩展。
(let* ((root (path-join (path-temp-dir) "pi-discover-library-override"))
       (home (path-join root "home"))
       (project (path-join root "project"))
       (user-dir (path-join home ".gf" "gfcode"))
       (project-dir (path-join project ".gf" "gfcode"))
       (saved-home (get-environment-variable "HOME"))
       (saved-profile (get-environment-variable "USERPROFILE"))
       (saved-gf (get-environment-variable "GF_CONFIG_DIR"))
       (saved-pi (get-environment-variable "PI_CODING_AGENT_DIR"))
      ) ;
  (path-mkdir user-dir :parents #t :exist-ok #t)
  (path-mkdir project-dir :parents #t :exist-ok #t)
  (path-write-text (path-join user-dir "shared.scm") (%probe-source "shared"))
  (path-write-text (path-join project-dir "shared.scm") (%probe-source "shared"))
  (putenv "HOME" (path->string home))
  (when (os-windows?)
    (putenv "USERPROFILE" (path->string home))
  ) ;when
  (unsetenv "GF_CONFIG_DIR")
  (unsetenv "PI_CODING_AGENT_DIR")
  (let* ((entries (pi-discover-extensions :cwd (path->string project) :builtin-dir %FIX))
         (matches
           (filter (lambda (entry) (equal? (%entry-name entry) '(gfcode shared))) entries)
         ) ;matches
        ) ;
    (check (length matches) => 1)
    (check (cdr (assq 'path (car matches)))
      =>
      (string-replace (path->string (path-resolve (path-join project-dir "shared.scm")))
        "\\"
        "/"
      ) ;string-replace
    ) ;check
  ) ;let*
  (if saved-home (putenv "HOME" saved-home) (unsetenv "HOME"))
  (when (os-windows?)
    (if saved-profile (putenv "USERPROFILE" saved-profile) (unsetenv "USERPROFILE"))
  ) ;when
  (if saved-gf (putenv "GF_CONFIG_DIR" saved-gf) (unsetenv "GF_CONFIG_DIR"))
  (if saved-pi
    (putenv "PI_CODING_AGENT_DIR" saved-pi)
    (unsetenv "PI_CODING_AGENT_DIR")
  ) ;if
  (rmtree (path->string root) #t)
) ;let*

;; 3. include-builtin? #f 时不返回内置 fixture。
(let ((result (pi-discover-extensions
                :builtin-dir      (path-join (path %FIX) "gfcode")
                :include-builtin? #f
                :cwd              (path->string (path-temp-dir))
              ) ;pi-discover-extensions
      ) ;result
     ) ;
  (check-false
    (and
      (find (lambda (entry) (equal? (%entry-name entry) '(gfcode valid-ext1))) result)
      #t
    ) ;and
  ) ;check-false
) ;let

(check-report)
