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

    (define (%source-tree-extension-candidates)
      (let loop
        ((roots *load-path*) (acc '()))
        (if (null? roots)
          (reverse acc)
          (let ((root (path (car roots))))
            (loop (cdr roots)
              (if (path-file? (path-join root "liii/pi/code/cli.scm"))
                (cons (path-join (path-parent root) "extensions") acc)
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
                   ;; 内置扩展优先匹配实际加载的 Pi 源目录，避免 cwd
                   ;; 下的同名 extensions 混入另一套 Pi 库。
                   (append (%source-tree-extension-candidates)
                     (list (path "extensions") (path "../extensions"))
                   ) ;append
                 ) ;candidates
                 (found
                   (find (lambda (c) (and (path-exists? c) (path-dir? c))) candidates)
                 ) ;found
                ) ;
            (if found (path->string (path-resolve found)) "extensions")
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (%entry-candidate dir-str name)
      (if (or (string-null? name) (char=? (string-ref name 0) #\.))
        #f
        (let* ((sub-path (path-join (path dir-str) name))
               (full-sub-str (path->string (path-resolve sub-path)))
              ) ;
          (cond
           ((and (path-file? sub-path) (string=? (path-suffix sub-path) ".scm"))
            full-sub-str
           ) ;
           ((path-dir? sub-path)
            (let ((index-path (path-join sub-path "index.scm")))
              (if (and (path-exists? index-path) (path-file? index-path))
                (path->string (path-resolve index-path))
                #f
              ) ;if
            ) ;let
           ) ;
           (else #f)
          ) ;cond
        ) ;let*
      ) ;if
    ) ;define

    (define (pi-scan-extension-dir dir)
      (let ((p (if (path? dir) dir (path dir))))
        (if (not (and (path-exists? p) (path-dir? p)))
          '()
          (let* ((dir-str (path->string (path-resolve p)))
                 (entries (catch #t (lambda () (listdir dir-str)) (lambda args '())))
                 (results '())
                ) ;
            (for-each
              (lambda (name)
                (let ((cand (%entry-candidate dir-str name)))
                  (if cand (set! results (cons cand results)))
                ) ;let
              ) ;lambda
              entries
            ) ;for-each
            (list-sort string<? results)
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (%dir-entries-if-valid dir-str)
      (if (and (string? dir-str) (path-exists? (path dir-str)) (path-dir? (path dir-str)))
        (pi-scan-extension-dir dir-str)
        '()
      ) ;if
    ) ;define

    (define (%resolve-explicit-items explicit cwd-dir)
      (map (lambda (item) (pi-resolve-path item cwd-dir))
        (filter
          (lambda (item)
            (and (string? item) (not (string-null? (string-trim-both item))))
          ) ;lambda
          (if (list? explicit) explicit '())
        ) ;filter
      ) ;map
    ) ;define

    (define (%extension-name path-str)
      (let* ((p (path path-str))
             (filename (path-name p))
             (name (if (string=? filename "index.scm") (path-name (path-parent p)) filename))
            ) ;
        (if (string-ends? name ".scm")
          (substring name 0 (- (string-length name) 4))
          name
        ) ;if
      ) ;let*
    ) ;define

    (define (%normalize-extension-paths paths)
      (map
        (lambda (p) (path->string (path-resolve (path p))))
        paths
      ) ;map
    ) ;define

    (define (%extension-entries paths)
      (map (lambda (p) (cons (%extension-name p) p))
        (%normalize-extension-paths paths)
      ) ;map
    ) ;define

    (define (%upsert-extension entries name path-str)
      (let ((replaced #f))
        (let ((updated
                (map
                  (lambda (entry)
                    (if (string=? (car entry) name)
                      (begin
                        (set! replaced #t)
                        (cons name path-str)
                      ) ;begin
                      entry
                    ) ;if
                  ) ;lambda
                  entries
                ) ;map
              ) ;updated
             ) ;
          (if replaced updated (append updated (list (cons name path-str))))
        ) ;let
      ) ;let
    ) ;define

    (define (%merge-extension-layer entries paths protected-names)
      (for-each
        (lambda (entry)
          (unless (member (car entry) protected-names)
            (set! entries (%upsert-extension entries (car entry) (cdr entry)))
          ) ;unless
        ) ;lambda
        (%extension-entries paths)
      ) ;for-each
      entries
    ) ;define

    (define (pi-discover-extensions . options)
      (let* ((builtin-dir (if (memq :builtin-dir options)
                            (pi-keyword-value :builtin-dir options #f)
                            (pi-default-builtin-extensions-dir)
                          ) ;if
             ) ;builtin-dir
             (agent-dir (pi-keyword-value :agent-dir options (pi-get-agent-dir)))
             (cwd-dir (pi-keyword-value :cwd options (getcwd)))
             (explicit (pi-keyword-value :explicit-extensions options '()))
             (include-builtin? (pi-keyword-value :include-builtin? options #t))
             ;; gf 配置目录（GF_CONFIG_DIR → ~/.gf/agent）的扩展层：
             ;; 与 skills 发现逻辑对齐，使用户可在 ~/.gf/agent/extensions
             ;; 配置全局扩展（如 tps.scm），不必进入仓库即可生效。
             ;; agent-dir 默认亦为 ~/.gf/agent，二者默认重合；仅当显式设置
             ;; PI_CODING_AGENT_DIR 与 GF_CONFIG_DIR 不同时才作为独立层叠加。
             (gf-config-dir (pi-keyword-value :config-dir options (gf-get-config-dir)))
             (gf-config-dir-str (if (or (string? gf-config-dir) (path? gf-config-dir))
                                  (path->string (path-join gf-config-dir "extensions"))
                                  #f
                                ) ;if
             ) ;gf-config-dir-str
             (global-dir-str (if (or (string? agent-dir) (path? agent-dir))
                               (path->string (path-join agent-dir "extensions"))
                               #f
                             ) ;if
             ) ;global-dir-str
             (project-dir-str
               (if (string? cwd-dir)
                 (path->string (path-join (path cwd-dir) ".gf" "extensions"))
                 #f
               ) ;if
             ) ;project-dir-str
             (builtin-list (%dir-entries-if-valid builtin-dir))
             (gf-config-list (%dir-entries-if-valid gf-config-dir-str))
             (global-list (%dir-entries-if-valid global-dir-str))
             (project-list (%dir-entries-if-valid project-dir-str))
             (explicit-list (%resolve-explicit-items explicit cwd-dir))
             (builtin-names (map car (%extension-entries builtin-list)))
             ;; 用户级可覆盖内置；项目级可覆盖普通用户级，但不能覆盖内置名称。
             ;; include-builtin? 为 #f 时仍用内置名称仲裁，仅不重复返回内置文件。
             ;; 层级：内置 → gf 配置目录（~/.gf/agent/extensions）→
             ;;       agent 目录（~/.gf/agent/extensions，默认与上层重合）→
             ;;       项目级（.gf/extensions）→ 显式。
             (gf-config-entries (%merge-extension-layer (if include-builtin? (%extension-entries builtin-list) '())
                                  gf-config-list
                                  '()
                                ) ;%merge-extension-layer
             ) ;gf-config-entries
             (global-entries (%merge-extension-layer gf-config-entries global-list '()))
             (project-entries (%merge-extension-layer global-entries project-list builtin-names)
             ) ;project-entries
             (all-entries (%merge-extension-layer project-entries explicit-list '()))
            ) ;
        (map cdr all-entries)
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
