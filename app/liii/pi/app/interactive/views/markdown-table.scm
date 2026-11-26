;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views markdown-table)
  (export markdown-layout-lines layout-text layout-table?)
  (import (scheme base)
    (liii string)
    (liii list)
    (liii tui text-width)
    (liii cmark block table)
    (liii cmark block heading-code)
  ) ;import
  (begin
    (define-record-type <layout-line>
      (layout text table?)
      layout-line?
      (text layout-text)
      (table? layout-table?)
    ) ;define-record-type
    (define (field block name)
      (cdr (assq name block))
    ) ;define
    (define (pad text width align)
      (let* ((extra (- width (display-width text)))
             (left (cond ((eq? align 'right) extra)
                         ((eq? align 'center) (quotient extra 2))
                         (else 0)
                   ) ;cond
             ) ;left
            ) ;
        (string-append (make-string left #\space)
          text
          (make-string (- extra left) #\space)
        ) ;string-append
      ) ;let*
    ) ;define
    (define (delimiter align width)
      (let ((left (if (memq align '(center left)) ":" ""))
            (right (if (memq align '(center right)) ":" ""))
           ) ;
        (string-append left
          (make-string (- width (string-length left) (string-length right)) #\-)
          right
        ) ;string-append
      ) ;let
    ) ;define
    (define (row cells)
      (string-append "| " (string-join cells " | ") " |")
    ) ;define
    (define (format-block block)
      (let* ((align (field block 'alignments))
             (header (field block 'header))
             (body (field block 'rows))
             (widths
               (map
                 (lambda (a) (+ 3 (if (eq? a 'center) 2 (if (eq? a 'default) 0 1))))
                 align
               ) ;map
             ) ;widths
            ) ;
        (for-each
          (lambda (cells) (set! widths (map max widths (map display-width cells))))
          (cons header body)
        ) ;for-each
        (let ((width (+ 1 (* 3 (length widths)) (apply + widths))))
          (if
            (or (> width 2048) (> (* width (+ 2 (length body))) 16384))
            (field block 'lines)
            (map (lambda (cells) (row (map pad cells widths align)))
              (cons header (cons (map delimiter align widths) body))
            ) ;map
          ) ;if
        ) ;let
      ) ;let*
    ) ;define
    (define (markdown-layout-lines lines)
      (let loop
        ((ls lines) (fence #f))
        (cond ((null? ls) '())
              (fence
                (cons (layout (car ls) #f)
                  (loop (cdr ls)
                    (and (not (fenced-code-block-end? (car fence) (cadr fence) (car ls))) fence)
                  ) ;loop
                ) ;cons
              ) ;fence
              ((parse-fence-line (car ls))
               =>
               (lambda (f) (cons (layout (car ls) #f) (loop (cdr ls) f)))
              ) ;
              ((and (string-contains? (car ls) "|") (table-start? ls))
               (let ((block (collect-table-block ls)))
                 (append (map (lambda (s) (layout s #t)) (format-block (car block)))
                   (loop (cdr block) #f)
                 ) ;append
               ) ;let
              ) ;
              (else (cons (layout (car ls) #f) (loop (cdr ls) #f)))
        ) ;cond
      ) ;let
    ) ;define
  ) ;begin
) ;define-library
