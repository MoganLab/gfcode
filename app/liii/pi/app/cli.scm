;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi app cli)
  (import (scheme base)
    (scheme process-context)
    (scheme eval)
    (liii pi app cli help)
  ) ;import
  (export main display-pi-help read-all-stdin run-goldpi run-pi)
  (begin

    (define (strip-command-prefix args)
      (if (null? args)
        '()
        (let loop
          ((rest (cdr args)))
          (cond ((null? rest) '())
                ((or (string=? (car rest) "pi")
                   (and (>= (string-length (car rest)) 3)
                     (string=?
                       (substring (car rest)
                         (- (string-length (car rest)) 3)
                         (string-length (car rest))
                       ) ;substring
                       "/gf"
                     ) ;string=?
                   ) ;and
                 ) ;or
                 (cdr rest)
                ) ;
                (else (loop (cdr rest)))
          ) ;cond
        ) ;let
      ) ;if
    ) ;define

    (define (help-request? args)
      (or (equal? args '("-h")) (equal? args '("--help")))
    ) ;define

    (define (main-binding name)
      (eval name (environment '(liii pi app cli impl)))
    ) ;define

    (define (read-all-stdin)
     ((main-binding 'read-all-stdin))
    ) ;define

    (define (run-pi raw-args)
      (let ((args (strip-command-prefix raw-args)))
        (if (help-request? args)
          (begin
            (display-pi-help)
            0
          ) ;begin
          ((main-binding 'run-pi) raw-args)
        ) ;if
      ) ;let
    ) ;define

    (define run-goldpi run-pi)

    (define (main)
      (exit (run-pi (command-line)))
    ) ;define

  ) ;begin
) ;define-library
