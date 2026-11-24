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
    (liii tui component)
    (liii gfproject tools)
    (liii pi tui interactive common)
  ) ;import
  (begin

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

    ;; 页眉内容只随 version 变化，与宽度无关，故一次构造后复用
    (define (%header-lines version)
      (let* ((dot (%fg %c-mid " · "))
             (line1 (string-append " " (%fg-bold %c-brand "gfcode") (%fg %c-dim " v" version)))
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

    (define (make-pi-header . args)
      (let* ((version (%keyword-value :version args (%pi-tool-version)))
             (lines (%header-lines version))
             (comp (make-component :render (lambda (self width) lines)))
            ) ;
        (component-data-set! comp (list 'pi-header version))
        comp
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
