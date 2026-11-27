;; pi-load-extension
;; 加载失败时把错误以 ERROR 级别写入按天日志文件（pi-log-error!），
;; 方便插件开发者与使用者在 stderr 被 TUI 冲掉后仍能事后定位问题。
;;
;; 语法
;; ----
;; (pi-load-extension path-or-entry api . opt-context)
;;
;; 参数
;; ----
;; path-or-entry : (or string path)
;; library 扩展路径。
;;
;; api : (or extension-api extension-registry)
;; 扩展宿主 API 或注册表记录。
;;
;; opt-context : extension-context（可选）
;; 传给扩展工厂的上下文。
;;
;; 返回值
;; ----
;; alist
;; 包含 status、path 与 value 或 error 字段的加载结果。
;; 加载失败时向 pi 日志文件追加一行 extension-load path=... error="..."，
;; 错误类型（如 read-error）与 s7 错误格式串参数会展开成可读文本；
;; 写日志失败静默忽略，不影响加载结果；加载成功不产生日志。

(import (scheme base)
  (liii check)
  (liii path)
  (liii shutil)
  (liii string)
  (liii tempfile)
  (liii pi ai log)
  (liii pi code core extensions)
) ;import

(check-set-mode! 'report-failed)

(define *base* (make-temp-dir "gf-pi-load-ext-log-" ""))

(define *log-dir* (path-join (path *base*) "logs"))
(pi-log-init! *log-dir*)

(define (%read-log)
  (let ((f (pi-log-file-path)))
    (if (file-exists? (path->string f)) (path-read-text f) "")
  ) ;let
) ;define

;; 1. 语法错误的扩展：status 为 error，且日志中出现该扩展路径
(let* ((ext-dir (path-join (path *base*) "gfcode"))
       (file (path-join ext-dir "log-broken-ext.scm"))
      ) ;
  (path-mkdir ext-dir :parents #t :exist-ok #t)
  (path-write-text file "(define-library (gfcode log-broken-ext) (broken")
  (let ((res (pi-load-extension (path->string file) (make-extension-api))))
    (check (eq? (cdr (assq 'status res)) 'error) => #t)
    (check (string-contains? (%read-log) "extension-load") => #t)
    (check (string-contains? (%read-log) (path->string file)) => #t)
    (check (string-contains? (%read-log) "read-error") => #t)
    (check (string-contains? (%read-log) "missing close paren") => #t)
  ) ;let
) ;let*

;; 2. 工厂执行时抛错的扩展：错误类型同样落盘
;;    （经 define-library 边界后 s7 消息对象退化为循环结构，
;;    消息文本可能不可恢复，只断言错误 key 与路径）。
(let* ((ext-dir (path-join (path *base*) "gfcode"))
       (file (path-join ext-dir "log-raise-ext.scm"))
      ) ;
  (path-write-text file
    (string-append "(define-library (gfcode log-raise-ext)\n"
      "  (import (scheme base)) (export extension)\n"
      "  (begin (define (extension api) (error 'boom \"factory failed\"))))\n"
    ) ;string-append
  ) ;path-write-text
  (let ((res (pi-load-extension (path->string file) (make-extension-api))))
    (check (eq? (cdr (assq 'status res)) 'error) => #t)
    (check (string-contains? (%read-log) (path->string file)) => #t)
    (check (string-contains? (%read-log) "boom") => #t)
  ) ;let
) ;let*

;; 3. 加载成功不产生 extension-load 日志
(let* ((ext-dir (path-join (path *base*) "gfcode"))
       (file (path-join ext-dir "log-ok-ext.scm"))
       (before (%read-log))
      ) ;
  (path-write-text file
    (string-append "(define-library (gfcode log-ok-ext)\n"
      "  (import (scheme base)) (export extension)\n"
      "  (begin (define (extension api) \"ok\")))\n"
    ) ;string-append
  ) ;path-write-text
  (let ((res (pi-load-extension (path->string file) (make-extension-api))))
    (check (eq? (cdr (assq 'status res)) 'ok) => #t)
    (check (string=? (%read-log) before) => #t)
  ) ;let
) ;let*

(pi-log-reset!)
(rmtree *base* #t)

(check-report)
