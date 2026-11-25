;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code core extensions discovery)
  (import (scheme base)
    (scheme process-context)
    (liii string)
    (liii list)
    (liii path)
    (liii os)
    (liii sort)
    (liii pi code core tools read)
  ) ;import
  (export pi-scan-extension-dir
    pi-discover-extensions
    pi-default-builtin-extensions-dir
  ) ;export
  (begin

    ;; 源码树内的扩展候选目录：除 .gf/gfcode 外，各 domain 根下的
    ;; gfcode/ 目录（如 review/gfcode、web-search/gfcode）
    ;; 也参与内置发现；同一 gfcode 目录只收录一次。
    (define (%source-tree-extension-candidates)
      (let loop
        ((roots *load-path*) (acc '()))
        (if (null? roots)
          (reverse acc)
          (let* ((root (path (car roots)))
                 (gfcode-dir (path-join root "gfcode"))
                 (next-acc (if (path-dir? gfcode-dir) (cons gfcode-dir acc) acc))
                ) ;
            (loop (cdr roots)
              (let dedup
                ((rest next-acc) (seen '()) (out '()))
                (if (null? rest)
                  (reverse out)
                  (let ((key (%normalize-path (car rest))))
                    (dedup (cdr rest)
                      (cons key seen)
                      (if (member key seen) out (cons (car rest) out))
                    ) ;dedup
                  ) ;let
                ) ;if
              ) ;let
            ) ;loop
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (pi-default-builtin-extensions-dir)
      (let ((env-dir (get-environment-variable "PI_BUILTIN_EXTENSIONS_DIR")))
        (if
          (and (string? env-dir) (not (string-null? (string-trim-both env-dir))))
          env-dir
          (let* ((candidates (append (%source-tree-extension-candidates)
                               (list (path ".gf/gfcode") (path "../.gf/gfcode"))
                             ) ;append
                 ) ;candidates
                 (found
                   (find (lambda (c) (and (path-exists? c) (path-dir? c))) candidates)
                 ) ;found
                ) ;
            (if found (path->string (path-resolve found)) ".gf/gfcode")
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (%normalize-path p)
      (string-replace (path->string (path-resolve (path p))) "\\" "/")
    ) ;define

    (define (%path-relative-to root target)
      (let* ((root-str (%normalize-path root))
             (target-str (%normalize-path target))
             (prefix (string-append root-str "/"))
            ) ;
        (if (string-starts? target-str prefix)
          (substring target-str (string-length prefix) (string-length target-str))
          #f
        ) ;if
      ) ;let*
    ) ;define

    (define (%library-name root path-str)
      (let ((relative (%path-relative-to root path-str)))
        (if (and relative (string-ends? relative ".scm"))
          (map string->symbol
            (string-split (substring relative 0 (- (string-length relative) 4)) "/")
          ) ;map
          #f
        ) ;if
      ) ;let
    ) ;define

    (define (%library-entry root path-str)
      (let ((name (%library-name root path-str)))
        (and name
          (list (cons 'type 'library)
            (cons 'name name)
            (cons 'root (%normalize-path root))
            (cons 'path (%normalize-path path-str))
          ) ;list
        ) ;and
      ) ;let
    ) ;define

    (define (%valid-library-file? name)
      (and (not (string-null? name))
        (not (char=? (string-ref name 0) #\.))
        (string-ends? name ".scm")
      ) ;and
    ) ;define

    (define (%scan-library-tree root relative)
      (let ((dir (if (string-null? relative) (path root) (path-join (path root) relative)))
           ) ;
        (if (not (and (path-exists? dir) (path-dir? dir)))
          '()
          (let ((names
                  (catch #t
                    (lambda () (vector->list (listdir (path->string dir))))
                    (lambda args '())
                  ) ;catch
                ) ;names
               ) ;
            (append-map
              (lambda (name)
                (let* ((child-relative (if (string-null? relative) name (string-append relative "/" name))
                       ) ;child-relative
                       (child (path-join dir name))
                      ) ;
                  (cond
                   ((path-file? child)
                    (if (%valid-library-file? name) (list (%normalize-path child)) '())
                   ) ;
                   ((and (path-dir? child)
                      (not (string-null? name))
                      (not (char=? (string-ref name 0) #\.))
                    ) ;and
                    (%scan-library-tree root child-relative)
                   ) ;
                   (else '())
                  ) ;cond
                ) ;let*
              ) ;lambda
              (list-sort string<? names)
            ) ;append-map
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    (define (pi-scan-extension-dir dir)
      (let ((root (%normalize-path dir)))
        (if (and (path-exists? (path root)) (path-dir? (path root)))
          (map
            (lambda (p) (%library-entry (path-parent (path root)) p))
            (%scan-library-tree root "")
          ) ;map
          '()
        ) ;if
      ) ;let
    ) ;define

    (define (%extension-key entry)
      (let ((name (cdr (assq 'name entry))))
        (if (and (pair? name) (eq? (car name) 'gfcode))
          (string-join (map symbol->string (cdr name)) "/")
          (string-join (map symbol->string name) "/")
        ) ;if
      ) ;let
    ) ;define

    (define (%protected-extension? key protected-names)
      (let loop
        ((rest protected-names))
        (cond ((null? rest) #f)
              ((string=? key (car rest)) #t)
              (else (loop (cdr rest)))
        ) ;cond
      ) ;let
    ) ;define

    (define (%merge-extension-layer entries new-entries protected-names)
      (let ((result entries))
        (for-each
          (lambda (entry)
            (let* ((key (%extension-key entry))
                   (existing
                     (let find-existing
                       ((rest result))
                       (cond ((null? rest) #f)
                             ((string=? key (%extension-key (car rest))) (car rest))
                             (else (find-existing (cdr rest)))
                       ) ;cond
                     ) ;let
                   ) ;existing
                  ) ;
              (unless (%protected-extension? key protected-names)
                (if existing
                  (begin
                    (set-car! existing (car entry))
                    (set-cdr! existing (cdr entry))
                  ) ;begin
                  (set! result (append result (list entry)))
                ) ;if
              ) ;unless
            ) ;let*
          ) ;lambda
          new-entries
        ) ;for-each
        result
      ) ;let
    ) ;define

    (define (%config-library-root)
      (let ((config-dir (path (gf-get-config-dir))))
        (if (string=? (path-name config-dir) "agent")
          (path-parent config-dir)
          config-dir
        ) ;if
      ) ;let
    ) ;define

    (define (pi-discover-extensions . options)
      (let* ((builtin-option (if (memq ':builtin-dir options)
                               (pi-keyword-value :builtin-dir options #f)
                               (pi-default-builtin-extensions-dir)
                             ) ;if
             ) ;builtin-option
             (builtin-dir
               (if (string=? (path-name (path builtin-option)) "gfcode")
                 builtin-option
                 (path-join (path builtin-option) "gfcode")
               ) ;if
             ) ;builtin-dir
             (cwd-dir (pi-keyword-value :cwd options (getcwd)))
             (include-builtin? (pi-keyword-value ':include-builtin? options #t))
             (user-entries (pi-scan-extension-dir (path-join (%config-library-root) "gfcode"))
             ) ;user-entries
             (project-entries (pi-scan-extension-dir (path-join (path cwd-dir) ".gf" "gfcode"))
             ) ;project-entries
             ;; 内置层 = 默认内置目录 + 源码树各 domain 的 gfcode/ 目录；
             ;; 按归一化路径去重，同名扩展由 %merge-extension-layer 仲裁。
             ;; PI_BUILTIN_EXTENSIONS_DIR 显式指定时只用该目录，保证隔离。
             (builtin-dirs
               (let dedup
                 ((rest
                    (cond ((not include-builtin?) '())
                          ((get-environment-variable "PI_BUILTIN_EXTENSIONS_DIR")
                           =>
                           (lambda (dir) (list dir))
                          ) ;
                          (else (append (list builtin-dir)
                                  (%source-tree-extension-candidates)
                                  (list (path ".gf/gfcode") (path "../.gf/gfcode"))
                                ) ;append
                          ) ;else
                    ) ;cond
                  ) ;rest
                  (seen '())
                  (out '())
                 ) ;
                 (if (null? rest)
                   (reverse out)
                   (let ((key (%normalize-path (car rest))))
                     (dedup (cdr rest)
                       (cons key seen)
                       (if (member key seen) out (cons (car rest) out))
                     ) ;dedup
                   ) ;let
                 ) ;if
               ) ;let
             ) ;builtin-dirs
             (builtin-entries (append-map pi-scan-extension-dir builtin-dirs))
             (project-gfcode-dir (path-join (path cwd-dir) ".gf" "gfcode"))
             ;; 内置扩展与项目扩展统一位于 .gf/gfcode：cwd 的 .gf/gfcode 即内置目录
             ;; 时只扫描一次，避免同名副本重复注册；用户级 ~/.gf/gfcode 作为中间层。
             (builtin-is-project? (string=? (%normalize-path builtin-dir) (%normalize-path project-gfcode-dir))
             ) ;builtin-is-project?
             (protected-names '())
             (builtin-layer (%merge-extension-layer '() builtin-entries '()))
             (user-layer (%merge-extension-layer builtin-layer user-entries protected-names))
             (project-layer (%merge-extension-layer user-layer
                              (if builtin-is-project? '() project-entries)
                              protected-names
                            ) ;%merge-extension-layer
             ) ;project-layer
            ) ;
        project-layer
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
