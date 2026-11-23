;; pi-discover-extensions
;; 多层级扩展发现：合并内置、gf 配置目录、agent 目录、项目级、显式扩展路径，
;; 返回去重后的扩展入口脚本绝对路径列表。
;;
;; 语法
;; ----
;; (pi-discover-extensions . options)
;;
;; 参数
;; ----
;; options : 关键字参数（:builtin-dir / :agent-dir / :config-dir / :cwd /
;;           :explicit-extensions / :include-builtin?）
;;
;; 返回值
;; ----
;; list of string
;; 扩展入口脚本绝对路径，按层级合并并去重（同名首见胜出，内置名受保护）。

(import (scheme base)
  (liii check)
  (liii string)
  (liii path)
  (liii os)
  (liii shutil)
  (liii pi code core extensions discovery)
) ;import

(check-set-mode! 'report-failed)

(define %FIX (path->string (path-resolve "code/tests/fixtures/extensions")))

;; 工具：从结果列表中提取文件名集合

(define (%names paths)
  (map (lambda (p) (path-name (path p))) paths)
) ;define

(define (%resolved str)
  (path->string (path-resolve (path str)))
) ;define

;; 1. 显式扩展被纳入：:explicit-extensions 指向 fixture 内的 .scm 文件
(let ((ext (path->string (path-join (path %FIX) "valid-ext1.scm")))
      (res
        (pi-discover-extensions
          :explicit-extensions
          (list (path->string (path-join (path %FIX) "valid-ext1.scm")))
          :builtin-dir %FIX
          :agent-dir   %FIX
          :config-dir  %FIX
        ) ;pi-discover-extensions
      ) ;res
     ) ;
  (check-true (pair? res))
  (check-true (and (member (%resolved ext) res) #t))
) ;let

;; 2. 项目级扩展（cwd/.pi/extensions）被发现
(let ((proj-root (path-join (path-temp-dir) "pi-discover-extensions-proj")) (res #f))
  (let ((proj-ext (path->string (path-join proj-root ".pi" "extensions"))))
    (let ((ext-file (path->string (path-join (path proj-ext) "proj-ext.scm"))))
      (catch #t
        (lambda ()
          (path-mkdir (path proj-ext) :parents #t :exist-ok #t)
          (path-write-text (path ext-file) ";; proj ext\n(lambda (api) 'ok)\n")
          (set! res
            (pi-discover-extensions
              :cwd         (path->string proj-root)
              :builtin-dir %FIX
              :agent-dir   %FIX
              :config-dir  %FIX
            ) ;pi-discover-extensions
          ) ;set!
        ) ;lambda
        (lambda args (set! res '()))
      ) ;catch
      (check-true (and (member (%resolved ext-file) res) #t))
    ) ;let
  ) ;let
  (rmtree (path->string proj-root) #t)
) ;let

;; 3. 用户级目录可覆盖内置同名扩展（gf-config-dir 层覆盖 builtin-dir 层）
(let ((dup-root (path-join (path-temp-dir) "pi-discover-extensions-dup")))
  (let ((dup-ext-dir (path->string (path-join dup-root "extensions"))))
    (path-mkdir (path dup-ext-dir) :parents #t :exist-ok #t)
    (let ((dup-ext (path->string (path-join (path dup-ext-dir) "valid-ext1.scm"))))
      (path-write-text (path dup-ext) ";; override\n(lambda (api) 'dup)\n")
      (let ((res (pi-discover-extensions
                   :builtin-dir %FIX
                   :config-dir  (path->string dup-root)
                   :agent-dir   %FIX
                 ) ;pi-discover-extensions
            ) ;res
           ) ;
        (check-true (and (member (%resolved dup-ext) res) #t))
        (check-true
          (and
            (not
              (member
                (%resolved (path->string (path-join (path %FIX) "valid-ext1.scm")))
                res
              ) ;member
            ) ;not
            #t
          ) ;and
        ) ;check-true
      ) ;let
    ) ;let
  ) ;let
  (rmtree (path->string dup-root) #t)
) ;let

;; 4. include-builtin? #f 时不返回内置文件
(let ((res (pi-discover-extensions
             :builtin-dir      %FIX
             :agent-dir        %FIX
             :config-dir       %FIX
             :include-builtin? #f
           ) ;pi-discover-extensions
      ) ;res
     ) ;
  (let ((names (%names res)))
    (check-true (not (member "valid-ext1.scm" names)))
    (check-true (not (member "valid-pkg" names)))
    (check-true (and (list? res) #t))
  ) ;let
) ;let

;; 5. 返回值为绝对路径字符串列表
(let ((res (pi-discover-extensions :builtin-dir %FIX :agent-dir %FIX :config-dir %FIX)
      ) ;res
     ) ;
  (check-true (list? res))
  (for-each
    (lambda (p) (check-true (string? p)) (check-true (path-absolute? (path p))))
    res
  ) ;for-each
) ;let

(check-report)
