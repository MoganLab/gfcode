;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views ansi-lines)
  (export %diff-theme-revision %diff-rows? %diff-visual-lines %diff-card-rows)
  (import (scheme base)
    (liii list)
    (liii string)
    (liii tui text-width)
    (liii pi code utils shell)
    (liii pi app interactive views theme)
    (liii pi app interactive views highlight-view)
  ) ;import
  (begin
    (define %diff-theme-revision 1)
    (define palette
      (list (cons "Added" "\x1b;[38;2;190;242;200m")
        (cons "Removed" "\x1b;[38;2;255;190;190m")
        (cons "Header" "\x1b;[38;2;140;210;220m")
        (cons "File" %fg-accent)
        (cons "Normal" %fg-output)
      ) ;list
    ) ;define
    ;; Require full, consecutive coverage; a continuation byte cannot begin a span.
    (define (safe-row? row)
      (let* ((text (car row)) (n (string-length text)))
        (and (string=? text (sanitize-display-text text))
          (not (any (lambda (c) (string-contains? text c)) '("\n" "\r" "\t")))
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
                    (assoc (caddr s) palette)
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
      (and (pair? rows)
        (let loop
          ((rs rows) (bytes 0) (count 0))
          (or (null? rs)
            (and (pair? rs)
              (< count 8192)
              (pair? (car rs))
              (string? (caar rs))
              (let* ((n (string-length (caar rs))) (total (+ bytes n (if (zero? count) 0 1))))
                (and (<= n 65536)
                  (<= total 524288)
                  (safe-row? (car rs))
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

    (define (ansi-row row)
      (apply string-append
        (map
          (lambda (s)
            (string-append (cdr (assoc (caddr s) palette))
              (substring (car row) (car s) (+ (car s) (cadr s)))
              %fg-reset
            ) ;string-append
          ) ;lambda
          (cdr row)
        ) ;map
      ) ;apply
    ) ;define
    (define (%diff-visual-lines rows expanded? width)
      (let* ((hidden
               (if expanded? 0 (max 0 (- (length rows) 10)))
             ) ;hidden
             (shown (map ansi-row (if (> hidden 0) (take rows 10) rows)))
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
