;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi tui interactive header)
  (export make-pi-header pi-header?)
  (import (scheme base)
    (liii format base)
    (liii format color)
    (liii json)
    (liii path)
    (liii string)
    (liii sys)
    (srfi srfi-13)
    (liii tui component)
    (liii gfproject tools)
    (liii pi tui interactive common)
  ) ;import
  (begin

    ;; 库体顶层缓存本源码文件的绝对路径（运行期调用 library-file 会返回
    ;; 调用方文件，必须在此捕获）。用于判定正式安装 / 开发者模式。
    (define %self-source-file (library-file))

    ;; 正式安装布局：库位于 ~/.gf/site-lisp 之下；其余（如直接在本仓库
    ;; ~/git/gfcode2 运行）视为开发者模式。
    (define (%dev-mode?)
      (and %self-source-file
        (catch #t
          (lambda ()
            (not (path-starts-with? (path %self-source-file)
                   (path-join (path-home) ".gf" "site-lisp")
                 ) ;path-starts-with?
            ) ;not
          ) ;lambda
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    ;; 把绝对路径中的 home 前缀缩写成 ~，分隔符统一为 /。
    (define (%abbreviate-home dir)
      (let* ((posix (path-as-posix (path dir)))
             (home
               (catch #t (lambda () (path-as-posix (path-home))) (lambda args #f))
             ) ;home
            ) ;
        (if (and home (string-prefix? home posix))
          (let ((rest (substring posix (string-length home))))
            (if
              (or (string-null? rest)
                (and (> (string-length rest) 0) (char=? (string-ref rest 0) #\/))
              ) ;or
              (string-append "~" rest)
              posix
            ) ;if
          ) ;let
          posix
        ) ;if
      ) ;let*
    ) ;define

    ;; 源码仓库根：.../<repo>/tui/liii/pi/tui/interactive/header.scm 上溯 5 级。
    (define (%source-repo-root)
      (and %self-source-file
        (catch #t
          (lambda ()
            (let loop
              ((p (path-parent (path %self-source-file))) (n 0))
              (if (= n 5) (path->string p) (loop (path-parent p) (+ n 1)))
            ) ;let
          ) ;lambda
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    (define (pi-header? obj)
      (and (component? obj)
        (let ((d (component-data obj)))
          (and (pair? d) (eq? (car d) 'pi-header))
        ) ;let
      ) ;and
    ) ;define

    ;; 页眉配色（24-bit RGB）
    (define %c-brand '(138 190 183))
    (define %c-dim '(102 102 102))
    (define %c-mid '(128 128 128))

    ;; 上色：parts 逐段拼接
    (define (%fg c . parts)
      (show #f (apply as-true-color (cons c parts)))
    ) ;define

    ;; 品牌色加粗
    (define (%fg-bold c . parts)
      (show #f (as-bold (apply as-true-color (cons c parts))))
    ) ;define

    ;; 页眉内容只随 version 与开发者标记变化，与宽度无关，故一次构造后复用。
    ;; dev-suffix 为 #f（正式安装）或形如 " (~/git/gfcode2)" 的标记。
    (define (%header-lines version dev-suffix)
      (let* ((dot (%fg %c-mid " · "))
             (line1 (string-append " "
                      (%fg-bold %c-brand "gfcode")
                      (%fg %c-dim " v" version)
                      (or dev-suffix "")
                    ) ;string-append
             ) ;line1
             (line2 (string-append " "
                      (%fg %c-dim "escape")
                      (%fg %c-mid " interrupt")
                      dot
                      (%fg %c-dim "ctrl+c/ctrl+d")
                      (%fg %c-mid " clear/exit")
                      dot
                      (%fg %c-dim "ctrl+z")
                      (%fg %c-mid " undo")
                      dot
                      (%fg %c-dim "/")
                      (%fg %c-mid " commands")
                      dot
                      (%fg %c-dim "!")
                      (%fg %c-mid " bash")
                    ) ;string-append
             ) ;line2
             (line4 (%fg %c-dim
                      "Goldfish Scheme Agent can explain its own features and look up its docs. Ask it how to use or extend it."
                    ) ;%fg
             ) ;line4
            ) ;
        (list "" line1 line2 "" line4 "")
      ) ;let*
    ) ;define

    ;; 读取 gfcode 自身 gfproject.json 的 package.version 作为首屏版本号；
    ;; 解析失败或缺字段时回退到 Goldfish 的 (version)，保证总有展示值。
    (define (%pi-tool-version)
      (catch #t
        (lambda ()
          (let* ((bundle (gfproject-resolve-tool-bundle "pi"))
                 (base (bundle-ref bundle "tool_base_dir"))
                ) ;
            (if (not (string? base))
              (version)
              (let* ((file (path->string (path-join (path base) "gfproject.json")))
                     (pkg (json-ref (string->json (path-read-text file)) "package"))
                    ) ;
                (or (json-ref-string pkg "version" #f) (version))
              ) ;let*
            ) ;if
          ) ;let*
        ) ;lambda
        (lambda args (version))
      ) ;catch
    ) ;define

    ;; 开发者模式标记：显示源码仓库根（home 前缀缩写成 ~）；正式安装不显示。
    (define (%dev-suffix)
      (if (%dev-mode?)
        (let ((root (%source-repo-root)))
          (and root (%fg %c-dim " (" (%abbreviate-home root) ")"))
        ) ;let
        #f
      ) ;if
    ) ;define

    (define (make-pi-header . args)
      (let* ((version (%keyword-value :version args (%pi-tool-version)))
             (lines (%header-lines version (%dev-suffix)))
             (comp (make-component :render (lambda (self width) lines)))
            ) ;
        (component-data-set! comp (list 'pi-header version))
        comp
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
