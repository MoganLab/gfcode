;; Copyright (C) 2026 The Goldfish Scheme Authors
;; Licensed under the MIT License

(define-library (liii pi app interactive tool-diff)
  ;; Export the private helpers for the independent go session.
  (export %tool-diff %diff-snapshot-bytes %diff-lines %diff-common-edge
    %diff-lines-count-limit %diff-matrix %diff-operations %diff-hunks
    %diff-hunk-header %diff-preview %diff-write-hunk %diff-write-op
    %diff-compare-lines %diff-compare-middle %diff-middle-result %diff-cr-end
  ) ;export
  (import (scheme base)
    (scheme write)
    (only (liii base) call-with-output-string)
    (liii string)
  ) ;import
  (begin
    (define %diff-snapshot-bytes (* 256 1024))
    (define %diff-lines-count-limit 8192)

    (define (%diff-cr-end text cr size)
      (let ((next (+ cr 1)))
        (if (and (< next size) (char=? (string-ref text next) #\newline))
          (+ next 1)
          next
        ) ;if
      ) ;let
    ) ;define

    ;; Keep the newline in the comparison key so a missing final newline is
    ;; visible as a line change. Fold CRLF and bare CR like path-read-text.
    (define (%diff-lines text)
      (let ((size (string-length text)))
        (let loop
          ((i 0) (start 0) (lines '()) (count 0))
          (cond
           ((= i size)
            (cond ((= i start) (list->vector (reverse lines)))
                  ((< count %diff-lines-count-limit)
                   (list->vector (reverse (cons (substring text start i) lines)))
                  ) ;
                  (else #f)
            ) ;cond
           ) ;
           ((char=? (string-ref text i) #\return)
            (and (< count %diff-lines-count-limit)
              (let ((next (%diff-cr-end text i size))
                    (line (string-append (substring text start i) "\n"))
                   ) ;
                (loop next next (cons line lines) (+ count 1))
              ) ;let
            ) ;and
           ) ;
           ((char=? (string-ref text i) #\newline)
            (and (< count %diff-lines-count-limit)
              (let ((next (+ i 1)))
                (loop next next (cons (substring text start next) lines) (+ count 1))
              ) ;let
            ) ;and
           ) ;
           (else (loop (+ i 1) start lines count))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%diff-common-edge old new start end step limit)
      (let loop
        ((i start) (j end) (n 0))
        (if (and (< n limit) (string=? (vector-ref old i) (vector-ref new j)))
          (loop (+ i step) (+ j step) (+ n 1))
          n
        ) ;if
      ) ;let
    ) ;define

    ;; LCS of suffixes in the unmatched middle; index 0 is its LCS length.
    (define (%diff-matrix old new start n m stride cancelled?)
      (let ((cells (make-vector (* (+ n 1) stride) 0)))
        (do ((i (- n 1) (- i 1)))
          ((or (< i 0) (cancelled?)) (and (< i 0) cells))
          (let ((a (vector-ref old (+ start i))))
            (do ((j (- m 1) (- j 1)))
              ((< j 0))
              (let* ((k (+ (* i stride) j)) (down (+ k stride)))
                (vector-set! cells
                  k
                  (if (string=? a (vector-ref new (+ start j)))
                    (+ 1 (vector-ref cells (+ down 1)))
                    (max (vector-ref cells down) (vector-ref cells (+ k 1)))
                  ) ;if
                ) ;vector-set!
              ) ;let*
            ) ;do
          ) ;let
        ) ;do
      ) ;let
    ) ;define

    ;; Each op's two zero-based positions are counts *before* consuming a line.
    (define (%diff-operations old new start n m stride cells)
      (let loop
        ((i (- start)) (j (- start)) (ops '()))
        (let ((x (+ start i)) (y (+ start j)))
          (cond
           ((< i 0) (loop (+ i 1) (+ j 1) (cons (list #\space x y) ops)))
           ((and (>= i n) (>= j m))
            (if (= x (vector-length old))
              (list->vector (reverse ops))
              (loop (+ i 1) (+ j 1) (cons (list #\space x y) ops))
            ) ;if
           ) ;
           ((and (< i n) (< j m) (string=? (vector-ref old x) (vector-ref new y)))
            (loop (+ i 1) (+ j 1) (cons (list #\space x y) ops))
           ) ;
           ((or (= j m)
              (and (< i n)
                (>=
                  (vector-ref cells (+ (* (+ i 1) stride) j))
                  (vector-ref cells (+ (* i stride) j 1))
                ) ;>=
              ) ;and
            ) ;or
            (loop (+ i 1) j (cons (list #\- x y) ops))
           ) ;
           (else (loop i (+ j 1) (cons (list #\+ x y) ops)))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%diff-hunks ops)
      (let ((size (vector-length ops)))
        (let loop
          ((i 0) (start #f) (end 0) (hunks '()))
          (cond
           ((= i size) (reverse (if start (cons (cons start end) hunks) hunks)))
           ((char=? (car (vector-ref ops i)) #\space) (loop (+ i 1) start end hunks))
           (else
             (let ((lo (max 0 (- i 3))) (hi (min size (+ i 4))))
               (if (and start (<= lo end))
                 (loop (+ i 1) start hi hunks)
                 (loop (+ i 1) lo hi (if start (cons (cons start end) hunks) hunks))
               ) ;if
             ) ;let
           ) ;else
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%diff-hunk-header first last)
      (let* ((tag (car last))
             (x (cadr first))
             (y (caddr first))
             (n (+ (- (cadr last) x) (if (char=? tag #\+) 0 1)))
             (m (+ (- (caddr last) y) (if (char=? tag #\-) 0 1)))
            ) ;
        (string-append "@@ -"
          (number->string (if (zero? n) x (+ x 1)))
          ","
          (number->string n)
          " +"
          (number->string (if (zero? m) y (+ y 1)))
          ","
          (number->string m)
          " @@"
        ) ;string-append
      ) ;let*
    ) ;define

    (define (%diff-write-op old new op out)
      (let* ((tag (car op))
             (line (if (char=? tag #\+) (vector-ref new (caddr op)) (vector-ref old (cadr op)))
             ) ;line
             (end (- (string-length line) 1))
             (terminated? (char=? (string-ref line end) #\newline))
            ) ;
        (write-char tag out)
        (display (if terminated? (substring line 0 end) line) out)
        (newline out)
        (unless terminated?
          (display "\\ No newline at end of file" out)
          (newline out)
        ) ;unless
      ) ;let*
    ) ;define

    (define (%diff-write-hunk old new ops hunk out)
      (let ((start (car hunk)) (end (cdr hunk)))
        (display (%diff-hunk-header (vector-ref ops start) (vector-ref ops (- end 1)))
          out
        ) ;display
        (newline out)
        (do ((i start (+ i 1)))
          ((= i end))
          (%diff-write-op old new (vector-ref ops i) out)
        ) ;do
      ) ;let
    ) ;define

    (define (%diff-preview old new ops)
      (let* ((hunks (%diff-hunks ops))
             (text
               (call-with-output-string
                 (lambda (out)
                   (for-each (lambda (hunk) (%diff-write-hunk old new ops hunk out)) hunks)
                 ) ;lambda
               ) ;call-with-output-string
             ) ;text
            ) ;
        (and (<= (string-length text) (+ 1 (* 48 1024)))
          (string-trim-right text #\newline)
        ) ;and
      ) ;let*
    ) ;define

    (define (%diff-middle-result old new start n m stride cells with-text?)
      (let* ((shared (if cells (vector-ref cells 0) 0))
             (added (- m shared))
             (removed (- n shared))
             (changed (+ added removed))
             (ops (and with-text?
                    (<= 1 changed 200)
                    (%diff-operations old new start n m stride cells)
                  ) ;and
             ) ;ops
            ) ;
        (list (and ops (%diff-preview old new ops))
          added
          removed
          (and (> changed 0) (+ start 1))
        ) ;list
      ) ;let*
    ) ;define

    (define (%diff-compare-middle old new start n m with-text? cancelled?)
      (let* ((stride (+ m 1)) (matrix? (and (> n 0) (> m 0))))
        (and
          (or (not matrix?) (<= (* (+ n 1) stride) 250000))
          (let ((cells (and matrix? (%diff-matrix old new start n m stride cancelled?))))
            (and (or (not matrix?) cells)
              (not (cancelled?))
              (%diff-middle-result old new start n m stride cells with-text?)
            ) ;and
          ) ;let
        ) ;and
      ) ;let*
    ) ;define

    (define (%diff-compare-lines old new with-text? cancelled?)
      (let* ((old-size (vector-length old))
             (new-size (vector-length new))
             (limit (min old-size new-size))
             (start (%diff-common-edge old new 0 0 1 limit))
             (tail (%diff-common-edge old new (- old-size 1) (- new-size 1) -1 (- limit start))
             ) ;tail
            ) ;
        (%diff-compare-middle old
          new
          start
          (- old-size start tail)
          (- new-size start tail)
          with-text?
          cancelled?
        ) ;%diff-compare-middle
      ) ;let*
    ) ;define

    (define* (%tool-diff before after (with-text? #t) (cancelled? (lambda () #f)))
      (unless (and (string? before) (string? after))
        (error 'type-error "%tool-diff: expected before/after text strings")
      ) ;unless
      (and (<= (max (string-length before) (string-length after)) %diff-snapshot-bytes)
        (if (string=? before after)
          '(#f 0 0 #f)
          (let ((old (%diff-lines before)) (new (%diff-lines after)))
            (and old new (%diff-compare-lines old new with-text? cancelled?))
          ) ;let
        ) ;if
      ) ;and
    ) ;define*
  ) ;begin
) ;define-library
