;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code core extensions install)
  (import (scheme base)
    (scheme char)
    (liii string)
    (liii list)
    (liii path)
    (liii os)
    (liii subprocess)
    (liii error)
    (liii either)
    (liii shutil)
    (liii pi code core tools read)
    (liii pi code core failure)
  ) ;import
  (export pi-parse-git-extension-name pi-valid-extension-name?
    pi-resolve-install-target pi-git-clone-extension pi-install-extension
    pi-resolve-link-source pi-link-extension
  ) ;export
  (begin

    (define (%trim-git-trailing-separator trimmed)
      (let ((len (string-length trimmed)))
        (if
          (and (> len 1)
            (or (char=? (string-ref trimmed (- len 1)) #\/)
              (char=? (string-ref trimmed (- len 1)) #\\)
            ) ;or
          ) ;and
          (substring trimmed 0 (- len 1))
          trimmed
        ) ;if
      ) ;let
    ) ;define

    (define (%git-last-segment text)
      (let ((idx
              (string-index-right text
                (lambda (ch) (or (char=? ch #\/) (char=? ch #\\) (char=? ch #\:)))
              ) ;string-index-right
            ) ;idx
           ) ;
        (if idx (string-drop text (+ idx 1)) text)
      ) ;let
    ) ;define

    (define (%strip-git-suffix name)
      (if (and (> (string-length name) 4) (string-ends? (string-downcase name) ".git"))
        (substring name 0 (- (string-length name) 4))
        name
      ) ;if
    ) ;define

    (define (pi-parse-git-extension-name url)
      (if (not (string? url))
        #f
        (let* ((trimmed (string-trim-both url))
               (last-seg (%git-last-segment (%trim-git-trailing-separator trimmed)))
              ) ;
          (if (string-null? last-seg) #f (%strip-git-suffix last-seg))
        ) ;let*
      ) ;if
    ) ;define

    (define (pi-valid-extension-name? name)
      (and (string? name)
        (not (string-null? name))
        (string-every (lambda (ch)
                        (or (char-alphabetic? ch) (char-numeric? ch) (char=? ch #\-) (char=? ch #\_))
                      ) ;lambda
          name
        ) ;string-every
      ) ;and
    ) ;define

    (define (pi-resolve-install-target name . opts)
      (unless (string? name)
        (type-error "pi-resolve-install-target: name must be a string")
      ) ;unless
      (unless (pi-valid-extension-name? name)
        (value-error (string-append "Invalid extension name: " name))
      ) ;unless
      (let* ((local? (pi-keyword-value :local? opts #f))
             (agent-dir (path (pi-keyword-value :agent-dir opts (pi-get-agent-dir))))
             (cwd-dir (pi-keyword-value :cwd opts (getcwd)))
             (user-root (if (string=? (path-name agent-dir) "agent") (path-parent agent-dir) agent-dir)
             ) ;user-root
             (base-dir (if local?
                         (path-join (path cwd-dir) ".gf" "gfcode")
                         (path-join user-root "gfcode")
                       ) ;if
             ) ;base-dir
             (target-path (path-join base-dir (string-append name ".scm")))
            ) ;
        (path->string (path-resolve target-path))
      ) ;let*
    ) ;define

    ;; 链接目标 = 安装目标去掉 .scm 后缀（单文件目标为 <name>.scm，
    ;; 链接目标为同名目录 <name>）。
    (define (%link-target name opts)
      (let* ((target (apply pi-resolve-install-target name opts))
             (len (string-length target))
            ) ;
        (substring target 0 (- len 4))
      ) ;let*
    ) ;define

    ;; 解析本地扩展目录，返回 (cons name source-dir)。
    ;; 优先级：包目录 gfcode/<name>/index.scm > 单文件 <name>.scm。
    (define (pi-resolve-link-source dir)
      (let ((p (path dir)))
        (unless (and (path-exists? p) (path-dir? p))
          (value-error (string-append "Link source is not a directory: " (path->string p))
          ) ;value-error
        ) ;unless
        (let* ((pkg-root (path-join p "gfcode")) (pkg-name (%find-package-name pkg-root)))
          (if pkg-name
            (cons pkg-name (path->string (path-resolve (path-join pkg-root pkg-name))))
            (let ((single (%find-single-file p)))
              (if single
                (cons single (path->string (path-resolve p)))
                (value-error (string-append "No extension found in "
                               (path->string p)
                               ": expected gfcode/<name>/index.scm or <name>.scm"
                             ) ;string-append
                ) ;value-error
              ) ;if
            ) ;let
          ) ;if
        ) ;let*
      ) ;let
    ) ;define

    (define (%find-package-name pkg-root)
      (if (and (path-exists? pkg-root) (path-dir? pkg-root))
        (let loop
          ((names (vector->list (path-list pkg-root))))
          (cond ((null? names) #f)
                ((%package-entry? pkg-root (car names)) (car names))
                (else (loop (cdr names)))
          ) ;cond
        ) ;let
        #f
      ) ;if
    ) ;define

    (define (%package-entry? pkg-root name)
      (and (pi-valid-extension-name? name)
        (let ((entry (path-join pkg-root name "index.scm")))
          (and (path-exists? entry) (path-file? entry))
        ) ;let
      ) ;and
    ) ;define

    (define (%find-single-file p)
      (let loop
        ((names (vector->list (path-list p))))
        (cond ((null? names) #f)
              ((%single-entry? (car names))
               (substring (car names) 0 (- (string-length (car names)) 4))
              ) ;
              (else (loop (cdr names)))
        ) ;cond
      ) ;let
    ) ;define

    (define (%single-entry? name)
      (and (string-ends? name ".scm")
        (not (string=? name "index.scm"))
        (pi-valid-extension-name? (substring name 0 (- (string-length name) 4)))
      ) ;and
    ) ;define

    ;; 建目录链接：Windows 用 mklink /J（junction，免管理员/开发者模式），
    ;; Unix 用 ln -s。Windows 必须用原生反斜杠路径：mklink 会把正斜杠
    ;; 路径段（如 /Users）误判为命令行开关。
    (define (%make-dir-link src dst)
      (let* ((src-str (path->string (path-resolve (path src))))
             (dst-str (path->string (path-resolve (path dst))))
             (cmd (if (os-windows?)
                    (list "cmd" "/c" "mklink" "/J" dst-str src-str)
                    (list "ln" "-s" src-str dst-str)
                  ) ;if
             ) ;cmd
            ) ;
        (let ((res (run-either cmd :timeout 30 :stdout 'capture :stderr 'capture)))
          (unless (either-right? res)
            (error 'install-error
              (string-append "Failed to link extension: "
                (pi-command-failure-detail (to-left res))
              ) ;string-append
            ) ;error
          ) ;unless
        ) ;let
      ) ;let*
    ) ;define

    ;; 把本地扩展目录链接到用户级 ~/.gf/gfcode/<name> 或项目级
    ;; {cwd}/.gf/gfcode/<name>（:local? #t），供开发联调。
    ;; 返回链接目标路径字符串；目标已存在时报错。
    (define (pi-link-extension dir . opts)
      (let* ((resolved (pi-resolve-link-source dir))
             (name (car resolved))
             (src (cdr resolved))
             (target (%link-target name opts))
            ) ;
        (when (path-exists? (path target))
          (value-error (string-append "Link target already exists: " target))
        ) ;when
        (unless (path-exists? (path-parent (path target)))
          (path-mkdir (path-parent (path target)) :parents #t :exist-ok #t)
        ) ;unless
        (%make-dir-link src target)
        target
      ) ;let*
    ) ;define

    ;; 注意：不可手写递归 rmdir 清理——Windows 下会穿透 junction/symlink
    ;; 删除链接目标的真实文件。rmtree 对链接只删链接本身。
    (define (%rmdir-rec d)
      (let ((p (if (path? d) d (path d))))
        (when (path-exists? p)
          (if (path-dir? p) (rmtree (path->string p) #t) (remove (path->string p)))
        ) ;when
      ) ;let
    ) ;define

    (define (pi-git-clone-extension url dest-dir-str . opts)
      (let* ((timeout (pi-keyword-value :timeout opts 120))
             (dest-path (path dest-dir-str))
             (parent-dir (path-parent dest-path))
            ) ;
        (when (path-exists? dest-path)
          (value-error (string-append "Target extension directory already exists: " dest-dir-str)
          ) ;value-error
        ) ;when
        ;; 确保父级 extensions 目录存在
        (unless (path-exists? parent-dir)
          (path-mkdir parent-dir :parents #t :exist-ok #t)
        ) ;unless
        (let ((res (run-either (list "git" "clone" url dest-dir-str)
                     :timeout timeout
                     :stdout  'capture
                     :stderr  'capture
                   ) ;run-either
              ) ;res
             ) ;
          (if (either-right? res)
            #t
            (let ((err-info (to-left res)))
              ;; 失败时清理半成品
              (when (path-exists? dest-path)
                (catch #t
                  (lambda ()
                    (if (path-dir? dest-path) (%rmdir-rec dest-path) (remove dest-dir-str))
                  ) ;lambda
                  (lambda args #f)
                ) ;catch
              ) ;when
              (error 'install-error
                (string-append "Failed to clone extension from "
                  url
                  ": "
                  (pi-command-failure-detail err-info)
                ) ;string-append
              ) ;error
            ) ;let
          ) ;if
        ) ;let
      ) ;let*
    ) ;define

    (define (pi-install-extension url . opts)
      (let* ((ext-name (pi-parse-git-extension-name url)))
        (unless (and ext-name (pi-valid-extension-name? ext-name))
          (value-error (string-append "Cannot infer valid extension name from URL: "
                         (object->string url)
                       ) ;string-append
          ) ;value-error
        ) ;unless
        (let* ((target-dir (apply pi-resolve-install-target ext-name opts))
               (timeout (pi-keyword-value :timeout opts 120))
              ) ;
          (let ((clone-dir (string-append target-dir ".clone")))
            (catch #t
              (lambda ()
                (pi-git-clone-extension url clone-dir :timeout timeout)
                (let ((source (path-join (path clone-dir) (string-append ext-name ".scm"))))
                  (unless (and (path-exists? source) (path-file? source))
                    (value-error (string-append "Extension repository must contain " ext-name ".scm")
                    ) ;value-error
                  ) ;unless
                  (unless (path-exists? (path-parent (path target-dir)))
                    (path-mkdir (path-parent (path target-dir)) :parents #t :exist-ok #t)
                  ) ;unless
                  (path-write-text (path target-dir) (path-read-text source))
                ) ;let
                (%rmdir-rec clone-dir)
                target-dir
              ) ;lambda
              (lambda args
                (when (path-exists? (path clone-dir))
                  (%rmdir-rec clone-dir)
                ) ;when
                (apply error args)
              ) ;lambda
            ) ;catch
          ) ;let
        ) ;let*
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
