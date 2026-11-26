;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode code-review interactive)
  (import (scheme base)
    (liii pi code cli args)
    (gfcode code-review args)
    (gfcode code-review modes)
  ) ;import
  (export pi-code-review-command)
  (begin

    (define %no-files-message
      "No changed files found. Specify file paths or make some changes first."
    ) ;define

    (define* (pi-code-review-command args ctx (prepare pi-prepare-code-review))
      (let* ((options (pi-parse-review-args args))
             (error-message (cdr (assoc 'error options)))
             (config (cdr (or (assoc 'config ctx) '(#f))))
            ) ;
        (if error-message
          (list (cons 'status 'error) (cons 'message error-message))
          (let* ((parsed
                   (list (cons 'messages (cdr (assoc 'files options)))
                     (cons 'review-ref (cdr (assoc 'ref options)))
                     (cons 'staged (cdr (assoc 'staged options)))
                     (cons 'code-review #t)
                     (cons 'no-auto-compact #t)
                     (cons 'no-skills #t)
                   ) ;list
                 ) ;parsed
                 (request (prepare parsed config))
                ) ;
            (if (eq? (cdr (assoc 'status request)) 'no-files)
              (list (cons 'status 'no-files) (cons 'message %no-files-message))
              (append request
                (list (cons 'parsed (pi-code-review-parsed parsed))
                  (cons 'config (pi-code-review-config config))
                  (cons 'on-finish pi-code-review-response)
                ) ;list
              ) ;append
            ) ;if
          ) ;let*
        ) ;if
      ) ;let*
    ) ;define*

  ) ;begin
) ;define-library
