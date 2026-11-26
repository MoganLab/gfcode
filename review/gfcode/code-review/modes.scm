;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode code-review modes)
  (import (scheme base)
    (scheme write)
    (liii string)
    (liii list)
    (liii pi code cli args)
    (liii pi agent tools)
    (liii pi ai message)
    (liii pi code modes output)
    (liii pi code modes flow)
    (gfcode code-review files)
    (gfcode code-review prompt)
    (gfcode code-review parse)
    (gfcode code-review format)
  ) ;import
  (export pi-prepare-code-review pi-code-review-parsed pi-code-review-config
    pi-code-review-response run-code-review-flow
  ) ;export
  (begin

    (define %review-system-prompt
      "You are a code reviewer operating inside pi. You have no tools: do not call, request, or simulate tool calls. All file contents to review are provided in the user message. Return only the JSON findings object requested there."
    ) ;define

    (define* (pi-prepare-code-review parsed
               cfg
               (collector pi-collect-changed-files)
               (file-records pi-review-file-records)
             ) ;pi-prepare-code-review
      (let* ((file-args (pi-args-ref parsed 'messages))
             (explicit (and (pair? file-args) file-args))
             (collected (collector
                          :ref     (or (pi-args-ref parsed 'review-ref) "HEAD")
                          :staged  (pi-args-ref parsed 'staged)
                          :files   explicit
                          :timeout (pi-resolve-timeout parsed cfg)
                        ) ;collector
             ) ;collected
             (paths (cdr (assoc 'paths collected)))
             (notice (cdr (assoc 'message collected)))
            ) ;
        (if (null? paths)
          (list (cons 'status 'no-files) (cons 'notice notice))
          (let ((records (file-records paths)))
            (list (cons 'status 'ok)
              (cons 'paths paths)
              (cons 'records records)
              (cons 'prompt (pi-build-review-prompt records))
              (cons 'notice notice)
            ) ;list
          ) ;let
        ) ;if
      ) ;let*
    ) ;define*

    (define (pi-code-review-parsed parsed)
      (if (pi-args-ref parsed 'system-prompt)
        parsed
        (cons (cons 'system-prompt %review-system-prompt)
          (filter
            (lambda (pair) (not (and (pair? pair) (eq? (car pair) 'system-prompt))))
            parsed
          ) ;filter
        ) ;cons
      ) ;if
    ) ;define

    (define (pi-code-review-config cfg)
      (cons (cons 'tools '())
        (filter
          (lambda (pair) (not (eq? (car pair) 'tools)))
          cfg
        ) ;filter
      ) ;cons
    ) ;define

    (define (%field alist key)
      (let ((pair (assoc key alist)))
        (if pair (cdr pair) '())
      ) ;let
    ) ;define

    (define (%normalize-blocks content)
      (let ((items (cond ((vector? content) (vector->list content))
                         ((list? content) content)
                         (else '())
                   ) ;cond
            ) ;items
           ) ;
        (map (lambda (blk) (if (pi-block? blk) (pi-block->json blk) blk)) items)
      ) ;let
    ) ;define

    (define (%message-alist msg)
      (cond ((pi-message? msg) (pi-message->json msg))
            ((pair? msg) msg)
            (else #f)
      ) ;cond
    ) ;define

    (define (%message-field key alt-key msg default)
      (let ((alist (%message-alist msg)))
        (if alist
          (let ((pair (or (assoc key alist) (assoc alt-key alist))))
            (if pair (cdr pair) default)
          ) ;let
          default
        ) ;if
      ) ;let
    ) ;define

    (define (%message-text msg)
      (let ((alist (%message-alist msg)))
        (if (not alist)
          ""
          (let* ((content (%field alist "content"))
                 (normalized (cons (cons "content" (%normalize-blocks content)) alist))
                ) ;
            (extract-assistant-text normalized)
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (%last-assistant-text msgs)
      (let loop
        ((rest (reverse msgs)))
        (cond ((null? rest) "")
              (else
                (let ((text (%message-text (car rest))))
                  (if (string-null? (string-trim-both text)) (loop (cdr rest)) text)
                ) ;let
              ) ;else
        ) ;cond
      ) ;let
    ) ;define

    (define (pi-code-review-response res-msgs)
      (let* ((last-msg (and (pair? res-msgs) (car (reverse res-msgs))))
             (stop-reason (%message-field "stopReason" 'stopReason last-msg #f))
             (err-msg (%message-field "errorMessage" 'errorMessage last-msg #f))
            ) ;
        (cond
         ((or (equal? stop-reason "error") (equal? stop-reason "aborted"))
          (list (cons 'status 'error)
            (cons 'message (or err-msg (string-append "Request " stop-reason)))
          ) ;list
         ) ;
         ((equal? stop-reason "length")
          (list (cons 'status 'error)
            (cons 'message
              "Response was truncated: the model reached its output token limit."
            ) ;cons
          ) ;list
         ) ;
         (else
           (let ((findings (pi-parse-review-findings (%last-assistant-text res-msgs))))
             (list (cons 'status 'ok) (cons 'report (pi-format-review-findings findings)))
           ) ;let
         ) ;else
        ) ;cond
      ) ;let*
    ) ;define

    (define (%print-review-result res-msgs)
      (let ((result (pi-code-review-response res-msgs)))
        (if (eq? (cdr (assoc 'status result)) 'error)
          (begin
            (display-stderr (cdr (assoc 'message result)))
            1
          ) ;begin
          (begin
            (display (cdr (assoc 'report result)))
            (newline)
            0
          ) ;begin
        ) ;if
      ) ;let
    ) ;define

    (define (run-code-review-flow parsed cfg mode)
      (let ((request (pi-prepare-code-review parsed cfg)))
        (if (eq? (cdr (assoc 'status request)) 'no-files)
          (let ((msg "No changed files found. Specify file paths or make some changes first."))
            (if (eq? mode 'json) (display-stderr msg) (begin (display msg) (newline)))
            0
          ) ;let
          (let ((notice (cdr (assoc 'notice request))))
            (when notice
              (display-stderr notice)
            ) ;when
            (let ((rcfg (pi-code-review-config cfg))
                  (review-parsed (pi-code-review-parsed parsed))
                  (prompt (cdr (assoc 'prompt request)))
                 ) ;
              (if (eq? mode 'json)
                (run-session-flow review-parsed rcfg prompt emit-json-event (lambda _ 0))
                (run-session-flow review-parsed rcfg prompt #f %print-review-result)
              ) ;if
            ) ;let
          ) ;let
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
