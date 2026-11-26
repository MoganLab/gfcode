;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views syntax)
  (export %make-diff-parser %merge-diff-spans %diff-text-budget? %worker-parser)
  (import (scheme base)
    (liii string)
    (liii highlight definition)
    (liii highlight highlighter)
    (liii pi code utils shell)
  ) ;import
  (begin
    (define (%diff-text-budget? text)
      (and (<= (string-length text) 524288)
        (let loop
          ((rest (string-split text "\n")) (count 0))
          (or (null? rest)
            (and (< count 8192)
              (<= (string-length (car rest)) 65536)
              (loop (cdr rest) (+ count 1))
            ) ;and
          ) ;or
        ) ;let
      ) ;and
    ) ;define
    (define (%merge-diff-spans row)
      (let loop
        ((rest (car row)) (out '()))
        (if (null? rest)
          (cons (cdr row) (reverse out))
          (let* ((sp (car rest))
                 (pos (car sp))
                 (n (cadr sp))
                 (role (caddr sp))
                 (style (if (member role '("Added" "Removed" "Header" "File")) role "Normal"))
                 (prev (and (pair? out) (car out)))
                ) ;
            (loop (cdr rest)
              (if
                (and prev (string=? style (caddr prev)) (= pos (+ (car prev) (cadr prev))))
                (cons (list (car prev) (+ n (cadr prev)) style) (cdr out))
                (cons (list pos n style) out)
              ) ;if
            ) ;loop
          ) ;let*
        ) ;if
      ) ;let
    ) ;define
    (define (%make-diff-parser loader parse)
      (let ((definition 'unloaded))
        (lambda (raw)
          (catch #t
            (lambda ()
              (let ((text
                      (string-trim-right (string-replace (string-replace (sanitize-display-text raw) "\r" "") "\t" "   ")
                        #\newline
                      ) ;string-trim-right
                    ) ;text
                   ) ;
                (and (not (string=? text ""))
                  (%diff-text-budget? text)
                  (begin
                    (when (eq? definition 'unloaded)
                      (set! definition #f)
                      (set! definition (loader))
                    ) ;when
                    definition
                  ) ;begin
                  (map %merge-diff-spans (parse text definition))
                ) ;and
              ) ;let
            ) ;lambda
            (lambda args #f)
          ) ;catch
        ) ;lambda
      ) ;let
    ) ;define
    (define (%worker-parser)
      (%make-diff-parser (lambda () (load-syntax-definition "diff")) highlight-text)
    ) ;define
  ) ;begin
) ;define-library
