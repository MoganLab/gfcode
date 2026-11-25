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
  (export pi-scan-extension-dir pi-discover-extensions pi-default-builtin-extensions-dir)
  (begin

    (define (%source-tree-extension-candidates)
      (let loop
        ((roots *load-path*) (acc '()))
        (if (null? roots)
          (reverse acc)
          (let ((root (path (car roots))))
            (loop (cdr roots)
              (if (path-file? (path-join root "liii/pi/code/cli.scm"))
                (cons (path-join (path-parent root) "gfcode") acc)
                acc
              ) ;if
            ) ;loop
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    (define (pi-default-builtin-extensions-dir)
      (let ((env-dir (get-environment-variable "PI_BUILTIN_EXTENSIONS_DIR")))
        (if
          (and (string? env-dir) (not (string-null? (string-trim-both env-dir))))
          env-dir
          (let* ((candidates
                   (append (%source-tree-extension-candidates)
                     (list (path "gfcode") (path "../gfcode"))
                   ) ;append
                 ) ;candidates
                 (found
                   (find (lambda (c) (and (path-exists? c) (path-dir? c))) candidates)
                 ) ;found
                ) ;
            (if found (path->string (path-resolve found)) "gfcode")
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
      (let ((dir (if (string-null? relative)
                   (path root)
                   (path-join (path root) relative)
                 ) ;if
           ) ;dir
          ) ;
        (if (not (and (path-exists? dir) (path-dir? dir)))
          '()
          (let ((names (catch #t
                         (lambda () (vector->list (listdir (path->string dir))))
                         (lambda args '())
                       ) ;catch
              ) ;names
               ) ;
            (append-map
              (lambda (name)
                (let* ((child-relative
                         (if (string-null? relative) name (string-append relative "/" name))
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
          (map (lambda (p) (%library-entry (path-parent (path root)) p))
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

    (define (%upsert-extension entries key new-entry)
      (display (list 'UPSERT-IN entries key new-entry)) (newline)
      (let loop
        ((rest entries) (acc '()))
        (cond ((null? rest) (reverse (cons (cons key new-entry) acc)))
              ((string=? (car (car rest)) key)
               (append (reverse acc) (list (cons key new-entry)) (cdr rest))
              ) ;
              (else (loop (cdr rest) (cons (car rest) acc)))
        ) ;cond
      ) ;let
    ) ;define

    (define (%merge-extension-layer entries new-entries protected-names)
      (let loop
        ((rest new-entries) (acc entries))
        (if (null? rest)
          acc
          (let ((key (%extension-key (car rest))))
            (loop (cdr rest)
              (if (%protected-extension? key protected-names)
                acc
                (%upsert-extension acc key (car rest))
              ) ;if
            ) ;loop
          ) ;let
        ) ;if
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
             (builtin-dir (if (string=? (path-name (path builtin-option)) "gfcode")
                            builtin-option
                            (path-join (path builtin-option) "gfcode")
                          ) ;if
             ) ;builtin-dir
             (cwd-dir (pi-keyword-value :cwd options (getcwd)))
             (include-builtin? (pi-keyword-value ':include-builtin? options #t))
             (user-entries (pi-scan-extension-dir (path-join (%config-library-root) "gfcode")))
             (project-entries
               (pi-scan-extension-dir (path-join (path cwd-dir) ".gf" "gfcode"))
             ) ;project-entries
             (builtin-entries (if include-builtin? (pi-scan-extension-dir builtin-dir) '()))
             (protected-names '())
             (user-layer (%merge-extension-layer '() user-entries protected-names))
             (project-layer (%merge-extension-layer user-layer project-entries protected-names))
             (all-entries (%merge-extension-layer project-layer builtin-entries '()))
            ) ;
        (map cdr all-entries)
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
