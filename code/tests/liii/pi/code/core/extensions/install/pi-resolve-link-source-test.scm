;; pi-resolve-link-source
;; 解析本地扩展目录，返回 (cons name source-dir)。
;;
;; 语法
;; ----
;; (pi-resolve-link-source dir) -> pair
;;
;; 参数
;; ----
;; dir : string
;; 本地扩展源码目录：包形式 gfcode/<name>/index.scm 或单文件 <name>.scm。
;;
;; 返回值
;; ------
;; pair
;; (cons <name> <source-dir>)；包形式 source-dir 为 gfcode/<name> 绝对路径，
;; 单文件形式为 dir 绝对路径。非目录、不存在、不含扩展时抛 value-error。

(import (scheme base)
  (liii check)
  (liii path)
  (liii shutil)
  (liii os)
  (liii pi code core extensions install)
) ;import

(check-set-mode! 'report-failed)

;; 1. 包形式目录：gfcode/<name>/index.scm 优先，source-dir 指向 gfcode/<name>
(let* ((temp
         (path-join (path-temp-dir)
           (string-append "gf-rls-pkg-" (number->string (getpid)))
         ) ;path-join
       ) ;temp
      ) ;
  (when (path-exists? temp)
    (rmtree (path->string temp) #t)
  ) ;when
  (path-mkdir temp :parents #t :exist-ok #t)
  (path-mkdir (path-join temp "gfcode" "my-plugin") :parents #t :exist-ok #t)
  (path-write-text (path-join temp "gfcode" "my-plugin" "index.scm")
    ";; pkg entry\n"
  ) ;path-write-text
  (let ((resolved (pi-resolve-link-source (path->string temp))))
    (check (car resolved) => "my-plugin")
    (check-true
      (string=? (cdr resolved)
        (path->string (path-resolve (path-join temp "gfcode" "my-plugin")))
      ) ;string=?
    ) ;check-true
  ) ;let
  (rmtree (path->string temp) #t)
) ;let*

;; 2. 单文件目录：根含 <name>.scm，source-dir 指向目录本身
(let* ((temp
         (path-join (path-temp-dir)
           (string-append "gf-rls-single-" (number->string (getpid)))
         ) ;path-join
       ) ;temp
      ) ;
  (when (path-exists? temp)
    (rmtree (path->string temp) #t)
  ) ;when
  (path-mkdir temp :parents #t :exist-ok #t)
  (path-write-text (path-join temp "standalone.scm") ";; single file extension\n")
  (let ((resolved (pi-resolve-link-source (path->string temp))))
    (check (car resolved) => "standalone")
    (check-true (string=? (cdr resolved) (path->string (path-resolve temp))))
  ) ;let
  (rmtree (path->string temp) #t)
) ;let*

;; 3. 包形式优先于单文件：同时存在时返回包名
(let* ((temp
         (path-join (path-temp-dir)
           (string-append "gf-rls-priority-" (number->string (getpid)))
         ) ;path-join
       ) ;temp
      ) ;
  (when (path-exists? temp)
    (rmtree (path->string temp) #t)
  ) ;when
  (path-mkdir temp :parents #t :exist-ok #t)
  (path-mkdir (path-join temp "gfcode" "pkg-wins") :parents #t :exist-ok #t)
  (path-write-text (path-join temp "gfcode" "pkg-wins" "index.scm") ";; pkg\n")
  (path-write-text (path-join temp "loose.scm") ";; loose single\n")
  (let ((resolved (pi-resolve-link-source (path->string temp))))
    (check (car resolved) => "pkg-wins")
  ) ;let
  (rmtree (path->string temp) #t)
) ;let*

;; 4. 不含扩展的目录抛 value-error
(let* ((temp
         (path-join (path-temp-dir)
           (string-append "gf-rls-empty-" (number->string (getpid)))
         ) ;path-join
       ) ;temp
      ) ;
  (when (path-exists? temp)
    (rmtree (path->string temp) #t)
  ) ;when
  (path-mkdir temp :parents #t :exist-ok #t)
  (path-write-text (path-join temp "README.txt") "not an extension")
  (check-catch 'value-error (pi-resolve-link-source (path->string temp)))
  (rmtree (path->string temp) #t)
) ;let*

;; 5. 不存在的目录抛 value-error
(check-catch 'value-error
  (pi-resolve-link-source "/non/existent/path/for/sure/rls-12345")
) ;check-catch

;; 6. 传入文件（而非目录）抛 value-error
(let* ((temp
         (path-join (path-temp-dir)
           (string-append "gf-rls-file-" (number->string (getpid)))
         ) ;path-join
       ) ;temp
       (file (path-join temp "afile.scm"))
      ) ;
  (when (path-exists? temp)
    (rmtree (path->string temp) #t)
  ) ;when
  (path-mkdir temp :parents #t :exist-ok #t)
  (path-write-text file ";; just a file\n")
  (check-catch 'value-error (pi-resolve-link-source (path->string file)))
  (rmtree (path->string temp) #t)
) ;let*

(check-report)
