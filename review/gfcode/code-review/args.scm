;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode code-review args)
  (import (scheme base) (liii base) (liii string) (liii list))
  (export pi-parse-review-args)
  (begin

    (define (%options files ref staged error)
      (list (cons 'files (reverse files))
        (cons 'ref ref)
        (cons 'staged staged)
        (cons 'error error)
      ) ;list
    ) ;define

    (define (pi-parse-review-args text)
      (let loop
        ((tokens (if (string-null? (string-trim-both text)) '() (string-tokenize text)))
         (files '())
         (ref "HEAD")
         (staged #f)
        ) ;
        (if (null? tokens)
          (%options files ref staged #f)
          (let ((token (car tokens)) (rest (cdr tokens)))
            (cond ((string=? token "--staged") (loop rest files ref #t))
                  ((string=? token "--ref")
                   (if (pair? rest)
                     (loop (cdr rest) files (car rest) staged)
                     (%options files ref staged "--ref requires a value")
                   ) ;if
                  ) ;
                  ((string-starts? token "--ref=")
                   (let ((value (substring token 6 (string-length token))))
                     (if (string-null? value)
                       (%options files ref staged "--ref requires a value")
                       (loop rest files value staged)
                     ) ;if
                   ) ;let
                  ) ;
                  ((string-starts? token "--")
                   (%options files ref staged (string-append "Unknown review option: " token))
                  ) ;
                  (else (loop rest (cons token files) ref staged))
            ) ;cond
          ) ;let
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
