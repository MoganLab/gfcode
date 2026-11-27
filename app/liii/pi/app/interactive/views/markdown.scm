;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views markdown)
  (export %make-markdown-parser %worker-markdown-parser %markdown-max-bytes)
  (import (scheme base)
    (scheme time)
    (scheme lazy)
    (liii list)
    (liii string)
    (liii highlight definition)
    (liii highlight block-render)
    (liii highlight stream)
    (liii highlight highlighter)
    (liii pi app interactive views markdown-table)
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
            ((member attr
               '("Import" "Extension" "Keyword" "ControlFlow" "Preprocessor"
                 "Table")
             ) ;member
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
    (define (highlight-lines lines definition deadline cache)
      ;; Reuse only an identical layout prefix. A growing table may resize
      ;; earlier cells; resume at its first changed row with the saved state.
      (let loop
        ((ls lines)
         (state (initial-highlight-state definition))
         (out '())
         (old (car cache))
         (saved '())
        ) ;
        (cond ((> (current-jiffy) deadline) #f)
              ((null? ls) (set-car! cache (reverse saved)) (reverse out))
              ((and (pair? old)
                 (equal? (layout-text (car ls)) (car (car (car old))))
                 (eq? (layout-table? (car ls)) (cadr (car old)))
               ) ;and
               (let ((entry (car old)))
                 (loop (cdr ls)
                   (caddr entry)
                   (cons (car entry) out)
                   (cdr old)
                   (cons entry saved)
                 ) ;loop
               ) ;let
              ) ;
              (else
                (let* ((layout (car ls)) (text (layout-text layout)))
                  (let-values (((spans next) (highlight-line text state definition)))
                    (let* ((styles (pack spans))
                           (marked
                             (if (and (layout-table? layout) (pair? styles))
                               (cons (list (caar styles) (cadar styles) "TableBorder") (cdr styles))
                               styles
                             ) ;if
                           ) ;marked
                          ) ;
                      (let ((row (cons text marked)))
                        (loop (cdr ls)
                          next
                          (cons row out)
                          '()
                          (cons (list row (layout-table? layout) next) saved)
                        ) ;loop
                      ) ;let
                    ) ;let*
                  ) ;let-values
                ) ;let*
              ) ;else
        ) ;cond
      ) ;let
    ) ;define
    (define (%make-markdown-parser loader)
      (let ((definition 'unloaded) (cache (list '())))
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
                    (highlight-lines (markdown-layout-lines lines) definition deadline cache)
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
    (define (styled-table-row definition text)
      (let-values (((spans next)
                    (highlight-line text (initial-highlight-state definition) definition)
                   ) ;
                  ) ;
        (let ((styles (pack spans)))
          (cons text
            (if (null? styles)
              styles
              (cons (list (caar styles) (cadar styles) "TableBorder") (cdr styles))
            ) ;if
          ) ;cons
        ) ;let
      ) ;let-values
    ) ;define

    ;; One cursor per unfinished card. A patch keeps stable rows by index;
    ;; only the active table may need earlier columns widened. The empty row
    ;; following a newline is a display placeholder, never a stable row.
    (define (make-cursor definition)
      (let ((stable 0)
            (fresh '())
            (table '())
            (fenced? #f)
            (fed "")
            (fragment "")
            (delivered 0)
            (patches '())
           ) ;
        (define (table-rows)
          (let* ((original (reverse table)) (layout (markdown-layout-lines (map car original))))
            (map
              (lambda (item row)
                (if (not (layout-table? item))
                  row
                  (styled-table-row definition (layout-text item))
                ) ;if
              ) ;lambda
              layout
              original
            ) ;map
          ) ;let*
        ) ;define
        (define (flush-table!)
          (when (pair? table)
            (set! fresh (append (reverse (table-rows)) fresh))
            (set! table '())
          ) ;when
        ) ;define
        (define (line! text newline spans events)
          (let ((row (cons text (pack spans))))
            (if (and (not fenced?) (null? events) (string-contains? text "|"))
              (set! table (cons row table))
              (begin
                (flush-table!)
                (set! fresh (cons row fresh))
              ) ;begin
            ) ;if
            (for-each
              (lambda (ev)
                (cond ((equal? (car ev) "fenced-code-open") (set! fenced? #t))
                      ((equal? (car ev) "fenced-code-close") (set! fenced? #f))
                ) ;cond
              ) ;lambda
              events
            ) ;for-each
          ) ;let
        ) ;define
        (define stream (make-structure-stream definition #f :line-sink line!))
        (define (emit! leaf)
          (structure-stream-feed! stream leaf)
          (set! delivered (+ delivered (string-length leaf)))
          (let ((break (string-index-right leaf #\newline)))
            (set! fragment
              (if break (substring leaf (+ break 1)) (string-append fragment leaf))
            ) ;set!
          ) ;let
          (flush-table!)
          (let* ((tail
                   (if (string-null? fragment)
                     '("")
                     (list fragment (list 0 (string-length fragment) "Plain"))
                   ) ;if
                 ) ;tail
                 (added (reverse fresh))
                ) ;
            (set! patches (cons (list delivered (append added (list tail)) stable) patches))
            (set! stable (+ stable (length added)))
            (set! fresh '())
          ) ;let*
        ) ;define
        (define (finish-tail!)
          (structure-stream-finish! stream)
          (flush-table!)
          (if (pair? patches)
            (let* ((p (car patches)) (prefix (reverse (cdr (reverse (cadr p))))))
              (set-car! patches (list delivered (append prefix (reverse fresh)) (caddr p)))
            ) ;let*
            (set! patches (list (list delivered (reverse fresh) stable)))
          ) ;if
        ) ;define
        (let ((feed
                (%make-markdown-block-feed definition
                  #f
                  emit!
                  8192
                  (lambda (blank) (set! delivered (+ delivered (string-length blank))))
                ) ;%make-markdown-block-feed
              ) ;feed
             ) ;
          (lambda (text final?)
            (and (string-starts? text fed)
              (begin
                (feed (substring text (string-length fed)) final?)
                (set! fed text)
                (when (and final? (not (string-null? fragment)))
                  (finish-tail!)
                ) ;when
                (let ((result (reverse patches)))
                  (set! patches '())
                  result
                ) ;let
              ) ;begin
            ) ;and
          ) ;lambda
        ) ;let
      ) ;let
    ) ;define

    (define (%worker-markdown-parser)
      (let ((definition (delay (load-syntax-definition "markdown"))) (cursors '()))
        (lambda (raw id final?)
          (let* ((cached (assv id cursors))
                 (cursor (if cached (cdr cached) (make-cursor (force definition))))
                 (text
                   (sanitize-display-text
                     (if final?
                       raw
                       (let ((nl (string-index-right raw #\newline)))
                         (if nl (substring raw 0 (+ nl 1)) "")
                       ) ;let
                     ) ;if
                   ) ;sanitize-display-text
                 ) ;text
                 (patch (cursor text final?))
                ) ;
            ;; A formerly incomplete display escape / UTF-8 sequence can
            ;; change the sanitized prefix. Restart only that card in that case.
            (unless patch
              (set! cursor (make-cursor (force definition)))
              (set! patch (cursor text final?))
            ) ;unless
            (when cached
              (set! cursors (filter (lambda (entry) (not (eq? entry cached))) cursors))
            ) ;when
            (unless final?
              (set! cursors (cons (cons id cursor) cursors))
            ) ;unless
            patch
          ) ;let*
        ) ;lambda
      ) ;let
    ) ;define
  ) ;begin
) ;define-library
