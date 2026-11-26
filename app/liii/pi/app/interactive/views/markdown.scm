;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views markdown)
  (export %make-markdown-parser %worker-markdown-parser %markdown-max-bytes)
  (import (scheme base)
    (scheme time)
    (liii string)
    (liii highlight definition)
    (liii highlight highlighter)
    (liii pi code utils shell)
  ) ;import
  (begin
    (define %markdown-max-bytes 16384)
    ;; Normalize engine attributes to a small UI vocabulary. Never transmit
    ;; the engine's fourth span field (a mutable definition in this session).
    (define (role attr)
      (cond ((member attr '("Normal" "Normal Text")) "Plain")
            ((equal? attr "Header H1") "Heading1")
            ((string-starts? attr "Header H") "Heading")
            ((member attr
               '("Added" "Removed" "File" "Header" "Code" "List" "Variable"
                 "Function")
             ) ;member
             attr
            ) ;
            ((equal? attr "Strong Text") "Strong")
            ((equal? attr "Strong-Emphasis Text") "StrongEmphasis")
            ((equal? attr "Blockquote") "Quote")
            ((member attr '("Link" "Auto-Link")) "Link")
            ((equal? attr "Emphasis Text") "Emphasis")
            ((equal? attr "Strikethrough Text") "Strike")
            ((member attr '("Import" "Extension" "Keyword" "ControlFlow"
                            "Preprocessor"))
             "Keyword"
            ) ;
            ((member attr
               '("String" "Char" "SpecialChar" "SpecialString" "VerbatimString"
                 "RegionMarker")
             ) ;member
             "String"
            ) ;
            ((equal? attr "BuiltIn") "Function")
            ((member attr '("DecVal" "Float" "BaseN" "Constant")) "Number")
            ((equal? attr "DataType") "Type")
            (else "Muted")
      ) ;cond
    ) ;define
    (define (span-role s)
      (let ((attr (caddr s)) (def (and (pair? (cdddr s)) (cadddr s))))
        (cond ((not def) (if (equal? attr "Code") "CodeBlock" (role attr)))
              ((member (definition-name def) '("Markdown" "Diff")) (role attr))
              (else (role (definition-item-data-def-style def attr)))
        ) ;cond
      ) ;let
    ) ;define
    (define (pack spans)
      (let loop
        ((ss spans) (out '()))
        (if (null? ss)
          (reverse out)
          (let* ((s (car ss)) (style (span-role s)) (n (cadr s)))
            (loop (cdr ss)
              (if (and (pair? out) (equal? style (caddar out)))
                (cons (list (caar out) (+ n (cadar out)) style) (cdr out))
                (cons (list (car s) n style) out)
              ) ;if
            ) ;loop
          ) ;let*
        ) ;if
      ) ;let
    ) ;define
    (define (highlight-lines lines definition deadline)
      (let loop
        ((ls lines) (state (initial-highlight-state definition)) (out '()))
        (cond ((> (current-jiffy) deadline) #f)
              ((null? ls) (reverse out))
              (else
                (let-values (((spans next) (highlight-line (car ls) state definition)))
                  (loop (cdr ls) next (cons (cons (car ls) (pack spans)) out))
                ) ;let-values
              ) ;else
        ) ;cond
      ) ;let
    ) ;define
    (define (%make-markdown-parser loader)
      (let ((definition 'unloaded))
        (lambda (raw)
          (catch #t
            (lambda ()
              (and (<= (string-length raw) %markdown-max-bytes)
                (let ((lines (string-split (sanitize-display-text raw) "\n"))
                      (deadline (+ (current-jiffy) (/ (jiffies-per-second) 10)))
                     ) ;
                  (and (<= (length lines) 128)
                    (not (any-long? lines))
                    (begin
                      (when (eq? definition 'unloaded)
                        (set! definition #f)
                        (set! definition (loader))
                      ) ;when
                      definition
                    ) ;begin
                    (highlight-lines lines definition deadline)
                  ) ;and
                ) ;let
              ) ;and
            ) ;lambda
            (lambda args #f)
          ) ;catch
        ) ;lambda
      ) ;let
    ) ;define
    (define (any-long? lines)
      (and (pair? lines)
        (or (> (string-length (car lines)) 2048) (any-long? (cdr lines)))
      ) ;and
    ) ;define
    (define (%worker-markdown-parser)
      (%make-markdown-parser (lambda () (load-syntax-definition "markdown")))
    ) ;define
  ) ;begin
) ;define-library
