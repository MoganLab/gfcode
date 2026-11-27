;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code core extensions loader)
  (import (scheme base)
    (scheme load)
    (scheme eval)
    (liii string)
    (liii list)
    (liii path)
    (liii pi code core extensions types)
  ) ;import
  (export pi-load-extension pi-load-extensions pi-load-results-success-count
    pi-load-results-failed-count
  ) ;export
  (begin

    (define (%entry-field entry key)
      (cond ((assq key entry) => cdr)
            (else #f)
      ) ;cond
    ) ;define

    (define (%extension-entry entry)
      (if (and (pair? entry) (eq? (%entry-field entry 'type) 'library))
        entry
        (let* ((path-str (if (path? entry) (path->string entry) entry))
               (p (path path-str))
               (filename (path-name p))
               (stem
                 (if (string-ends? filename ".scm")
                   (substring filename 0 (- (string-length filename) 4))
                   filename
                 ) ;if
               ) ;stem
               (parent-dir (path-parent p))
               ;; index.scm 位于扩展子目录内：库名为 (gfcode <dir> index)，
               ;; root 取 gfcode 目录本身；单文件入口仍为 (gfcode <stem>)。
               (index? (string=? stem "index"))
               (name
                 (if index?
                   (list 'gfcode (string->symbol (path-name parent-dir)) 'index)
                   (list 'gfcode (string->symbol stem))
                 ) ;if
               ) ;name
               (root (if index? (path-parent (path-parent parent-dir)) (path-parent parent-dir))
               ) ;root
              ) ;
          (list (cons 'type 'library)
            (cons 'name name)
            (cons 'root (path->string (path-resolve root)))
            (cons 'path (path->string (path-resolve p)))
          ) ;list
        ) ;let*
      ) ;if
    ) ;define

    (define (%call-with-library-root root thunk)
      (let ((saved-load-path *load-path*))
        (dynamic-wind
          (lambda ()
            (set! *load-path*
              (cons root (remove (lambda (p) (string=? p root)) *load-path*))
            ) ;set!
          ) ;lambda
          thunk
          (lambda () (set! *load-path* saved-load-path))
        ) ;dynamic-wind
      ) ;let
    ) ;define

    (define (%import-extension-factory library-name)
      (eval 'extension (environment library-name))
    ) ;define

    (define (%call-factory factory api ctx)
      (if
        (and ctx (> (car (arity factory)) 1))
        (factory api ctx)
        (factory api)
      ) ;if
    ) ;define

    (define (%load-library-extension entry api ctx)
      (let ((path-str (%entry-field entry 'path))
            (root (%entry-field entry 'root))
            (library-name (%entry-field entry 'name))
           ) ;
        (%call-with-library-root root
          (lambda ()
            (load path-str)
            (let ((factory (%import-extension-factory library-name)))
              (if (procedure? factory)
                (%call-factory factory api ctx)
                (value-error "Extension must export an extension procedure")
              ) ;if
            ) ;let
          ) ;lambda
        ) ;%call-with-library-root
      ) ;let
    ) ;define

    ;; 容错：把扩展根目录加入全局 *load-path*。
    ;;
    ;; go worker（独立 s7 会话）的前导 import 会重放主会话全部已加载库，
    ;; 但只恢复 *load-path*。扩展库经 %call-with-library-root 临时挂载根目录
    ;; 加载，加载完成后根目录即被移除；若扩展位于 load-path 之外（典型如
    ;; 用户级 ~/.gf/gfcode 的插件，尤其 Windows junction：path-resolve 在
    ;; Windows 不解析链接，root 停留在链接路径上），worker 前导 import 将
    ;; 找不到该扩展文件而抛 io-error，导致 worker 启动即死、TUI 全部任务
    ;; 无响应。故加载成功后把根目录常驻 *load-path*，保证任何会话（含 go
    ;; worker）都能重新 import 扩展库；加载失败则不注册，坏扩展只降级为
    ;; [WARN]，不会毒化 worker。
    (define (%register-library-root! root)
      (let ((root-str (path->string (path-resolve (path root)))))
        (unless (member root-str *load-path*)
          (set! *load-path* (append *load-path* (list root-str)))
        ) ;unless
      ) ;let
    ) ;define

    (define (pi-load-extension entry api . opt-context)
      (let* ((ctx (if (pair? opt-context) (car opt-context) #f))
             (api-obj (if (extension-api? api) api (make-extension-api api)))
             (desc (%extension-entry entry))
             (path-str (%entry-field desc 'path))
             (err-p (if (defined? '*stderr*) *stderr* (current-error-port)))
            ) ;
        (catch #t
          (lambda ()
            (let ((value (%load-library-extension desc api-obj ctx)))
              (%register-library-root! (%entry-field desc 'root))
              (list (cons 'status 'ok) (cons 'path path-str) (cons 'value value))
            ) ;let
          ) ;lambda
          (lambda (key . args)
            (let ((message (string-append (object->string key) ": " (object->string args))))
              (display (string-append "[WARN] failed to load extension " path-str ": ") err-p)
              (display key err-p)
              (display " " err-p)
              (display args err-p)
              (newline err-p)
              (list (cons 'status 'error) (cons 'path path-str) (cons 'error message))
            ) ;let
          ) ;lambda
        ) ;catch
      ) ;let*
    ) ;define

    (define (pi-load-extensions entries api . opt-context)
      (let* ((ctx (if (pair? opt-context) (car opt-context) #f))
             (results
               (map (lambda (entry)
                      (if ctx (pi-load-extension entry api ctx) (pi-load-extension entry api))
                    ) ;lambda
                 (if (list? entries) entries '())
               ) ;map
             ) ;results
             (total (length results))
             (success
               (count
                 (lambda (r) (eq? (cdr (assq 'status r)) 'ok))
                 results
               ) ;count
             ) ;success
             (failed (- total success))
            ) ;
        (list (cons 'total total)
          (cons 'success success)
          (cons 'failed failed)
          (cons 'results results)
        ) ;list
      ) ;let*
    ) ;define

    (define (pi-load-results-success-count report)
      (if (pair? report) (cond ((assq 'success report) => cdr) (else 0)) 0)
    ) ;define

    (define (pi-load-results-failed-count report)
      (if (pair? report) (cond ((assq 'failed report) => cdr) (else 0)) 0)
    ) ;define

  ) ;begin
) ;define-library
