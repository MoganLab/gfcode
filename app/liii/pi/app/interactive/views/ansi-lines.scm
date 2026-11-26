;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views ansi-lines)
  (export %diff-theme-revision %diff-rows? %diff-visual-lines %diff-card-rows
    %markdown-rows? %markdown-visual-lines
  ) ;export
  (import (scheme base)
    (liii list)
    (liii string)
    (liii tui text-width)
    (liii pi code utils shell)
    (liii pi app interactive views theme)
    (liii pi app interactive views highlight-view)
  ) ;import
  (begin
    (define %diff-theme-revision 4)
    (define palette
      (list (cons "Added" %fg-added)
        (cons "Removed" %fg-removed)
        (cons "Header" %fg-output)
        (cons "File" %fg-output)
        (cons "Normal" %fg-output)
      ) ;list
    ) ;define
    ;; Resolved truecolor tokens from pi-coding-agent 1.4.0, dark.json.
    (define markdown-palette
      (append (list (cons "Plain" "")
                (cons "Strong" "\x1b;[1m")
                (cons "Emphasis" %italic)
                (cons "Strike" "\x1b;[9m")
                (cons "StrongEmphasis" "\x1b;[1m\x1b;[3m")
                (cons "Quote" (string-append %fg-output %italic))
                (cons "Link" "\x1b;[38;2;105;173;208m\x1b;[4m")
                (cons "CodeBlock" %fg-added)
                (cons "Code" %fg-accent)
                (cons "Heading1" (string-append %fg-warning "\x1b;[1m\x1b;[4m"))
                (cons "Heading" (string-append %fg-warning "\x1b;[1m"))
                (cons "List" %fg-accent)
                (cons "TableBorder" "\x1b;[38;2;105;173;208m")
                (cons "Keyword" "\x1b;[38;2;105;173;208m")
                (cons "Function" %fg-warning)
                (cons "Variable" "\x1b;[38;2;93;179;186m")
                (cons "String" "\x1b;[38;2;222;141;90m")
                (cons "Number" %fg-added)
                (cons "Type" %fg-accent)
                (cons "Muted" %fg-output)
              ) ;list
        palette
      ) ;append
    ) ;define
    ;; Require full, consecutive coverage; a continuation byte cannot begin a span.
    (define (safe-row? row styles markdown?)
      (let* ((text (car row)) (n (string-length text)))
        (and (string=? text (sanitize-display-text text))
          (if markdown?
            (not (string-contains? text "\n"))
            (not (any (lambda (c) (string-contains? text c)) '("\n" "\r" "\t")))
          ) ;if
          (let loop
            ((ss (cdr row)) (at 0))
            (if (null? ss)
              (= at n)
              (and (pair? ss)
                (let ((s (car ss)))
                  (and (list? s)
                    (= (length s) 3)
                    (exact-integer? (car s))
                    (= (car s) at)
                    (exact-integer? (cadr s))
                    (< 0 (cadr s))
                    (<= (+ at (cadr s)) n)
                    (not (<= 128 (char->integer (string-ref text at)) 191))
                    (assoc (caddr s) styles)
                    (loop (cdr ss) (+ at (cadr s)))
                  ) ;and
                ) ;let
              ) ;and
            ) ;if
          ) ;let
        ) ;and
      ) ;let*
    ) ;define
    (define (%diff-rows? rows)
      (valid-rows? rows #f)
    ) ;define
    (define (%markdown-rows? rows)
      (valid-rows? rows #t)
    ) ;define
    (define (valid-rows? rows markdown?)
      (and (pair? rows)
        (let loop
          ((rs rows) (bytes 0) (count 0))
          (or (null? rs)
            (and (pair? rs)
              (< count (if markdown? 128 8192))
              (pair? (car rs))
              (string? (caar rs))
              (let* ((n (string-length (caar rs))) (total (+ bytes n (if (zero? count) 0 1))))
                (and (<= n (if markdown? 2048 65536))
                  (<= total (if markdown? 16384 524288))
                  (safe-row? (car rs) (if markdown? markdown-palette palette) markdown?)
                  (loop (cdr rs) total (+ count 1))
                ) ;and
              ) ;let*
            ) ;and
          ) ;or
        ) ;let
      ) ;and
    ) ;define
    (define (%diff-card-rows view expanded? width bg)
      (and (%highlight-lines view)
        (catch #t
          (lambda ()
            (cons (apply-card-bg "" width bg %fg-output)
              (map (lambda (line) (apply-card-bg (string-append " " line) width bg %fg-output))
                (%diff-visual-lines (%highlight-lines view) expanded? (max 1 (- width 2)))
              ) ;map
            ) ;cons
          ) ;lambda
          (lambda args (%highlight-finish! view #f) #f)
        ) ;catch
      ) ;and
    ) ;define

    (define (ansi-row row styles reset)
      (apply string-append
        (map
          (lambda (s)
            (let ((code (cdr (assoc (caddr s) styles)))
                  (part (substring (car row) (car s) (+ (car s) (cadr s))))
                 ) ;
              (if (string=? code "") part (string-append code part reset))
            ) ;let
          ) ;lambda
          (cdr row)
        ) ;map
      ) ;apply
    ) ;define
    (define (%markdown-visual-lines rows width)
      (append-map
        (lambda (row)
          (let ((line (ansi-row row markdown-palette %ansi-reset)))
            (if
              (and (pair? (cdr row)) (equal? (caddr (cadr row)) "TableBorder"))
              (list line)
              (wrap-text line width)
            ) ;if
          ) ;let
        ) ;lambda
        rows
      ) ;append-map
    ) ;define
    (define (%diff-visual-lines rows expanded? width)
      (let* ((hidden
               (if expanded? 0 (max 0 (- (length rows) 10)))
             ) ;hidden
             (shown (map (lambda (row) (ansi-row row palette %fg-reset))
                      (if (> hidden 0) (take rows 10) rows)
                    ) ;map
             ) ;shown
            ) ;
        (wrap-text
          (string-join
            (if (zero? hidden)
              shown
              (append shown
                (list (string-append "... (" (number->string hidden) " more lines, ctrl+o to expand)")
                ) ;list
              ) ;append
            ) ;if
            "\n"
          ) ;string-join
          width
        ) ;wrap-text
      ) ;let*
    ) ;define
  ) ;begin
) ;define-library
