;; pi-load-extension
;; 加载成功后把扩展根目录常驻 *load-path*，保证 go worker 前导 import
;; 能重新找到扩展库（容错：load-path 之外的扩展不再毒化 worker 会话）。
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
;; 加载成功时扩展根目录被追加进 *load-path*（去重）；
;; 加载失败时 *load-path* 保持不变，坏扩展不影响后续 import。

(import (scheme base)
  (liii check)
  (liii list)
  (liii path)
  (liii shutil)
  (liii pi code core extensions)
) ;import

(check-set-mode! 'report-failed)

(define (%probe-source name)
  (string-append "(define-library (gfcode " name ")\n"
    "  (import (scheme base)) (export extension)\n"
    "  (begin (define (extension api) \"" name "-loaded\")))\n"
  ) ;string-append
) ;define

(define (%norm p)
  (path->string (path-resolve (path p)))
) ;define

;; 1. load-path 之外的扩展加载成功后，根目录常驻 *load-path*，
;;    且 dynamic-wind 的临时挂载已恢复（不残留重复条目）。
(let* ((root (path-join (path-temp-dir) "pi-load-ext-load-path"))
       (ext-dir (path-join root "gfcode"))
       (file (path-join ext-dir "lp-ext.scm"))
       (saved-load-path *load-path*)
      ) ;
  (path-mkdir ext-dir :parents #t :exist-ok #t)
  (path-write-text file (%probe-source "lp-ext"))
  (let* ((api (make-extension-api))
         (res (pi-load-extension (path->string file) api))
         (root-str (%norm root))
        ) ;
    (check (eq? (cdr (assq 'status res)) 'ok) => #t)
    (check (and (member root-str *load-path*) #t) => #t)
    (check (count (lambda (p) (string=? p root-str)) *load-path*) => 1)
    ;; 重复加载同一扩展不产生重复条目
    (pi-load-extension (path->string file) (make-extension-api))
    (check (count (lambda (p) (string=? p root-str)) *load-path*) => 1)
  ) ;let*
  (set! *load-path* saved-load-path)
  (rmtree (path->string root) #t)
) ;let*

;; 2. 加载失败的扩展不把根目录注册进 *load-path*（坏扩展只降级为
;;    status: error，不会让 worker 前导 import 失败）。
(let* ((root (path-join (path-temp-dir) "pi-load-ext-load-path-bad"))
       (ext-dir (path-join root "gfcode"))
       (file (path-join ext-dir "broken-ext.scm"))
       (saved-load-path *load-path*)
      ) ;
  (path-mkdir ext-dir :parents #t :exist-ok #t)
  (path-write-text file "(define-library (gfcode broken-ext) (broken")
  (let ((res (pi-load-extension (path->string file) (make-extension-api))))
    (check (eq? (cdr (assq 'status res)) 'error) => #t)
    (check (member (%norm root) *load-path*) => #f)
    (check (equal? *load-path* saved-load-path) => #t)
  ) ;let
  (set! *load-path* saved-load-path)
  (rmtree (path->string root) #t)
) ;let*

(check-report)
