;; Copyright (C) 2026 The Goldfish Scheme Authors
;; Licensed under the MIT License

(define-library (liii pi app interactive diff-worker)
  ;; All procedures reached by go must be visible in its separate session.
  (export %pi-display-worker %display-loop %diff-record-file! %diff-job!
    %diff-compute %diff-summary %make-diff-turn %diff-turn-id %diff-turn-done
    %diff-turn-files %diff-turn-control %diff-turn-control-set! %diff-turn-count
    %diff-turn-count-set! %diff-finish-turn %make-diff-file %diff-file-key
    %diff-file-path %diff-file-before %diff-file-after %diff-file-after-set!
    %diff-publish!
  ) ;export
  (import (scheme base)
    (liii go)
    (liii pi app interactive views markdown)
    (liii pi app interactive views syntax)
    (liii pi app interactive tool-diff)
    (only (liii unicode) utf8-replace-invalid)
  ) ;import
  (begin
    (define-record-type <diff-file>
      (%make-diff-file key path before after)
      %diff-file?
      (key %diff-file-key)
      (path %diff-file-path)
      (before %diff-file-before)
      (after %diff-file-after %diff-file-after-set!)
    ) ;define-record-type

    (define-record-type <diff-turn>
      (%make-diff-turn id done files control count)
      %diff-turn?
      (id %diff-turn-id)
      (done %diff-turn-done)
      (files %diff-turn-files)
      (control %diff-turn-control %diff-turn-control-set!)
      (count %diff-turn-count %diff-turn-count-set!)
    ) ;define-record-type

    (define (%diff-record-file! files key path before after)
      (when key
        ;; Sixteen slots cap retained baseline/after strings at 8 MiB.
        ;; A slot with #f after is permanently invalid; do not start a new
        ;; baseline after a successful write with no usable snapshot.
        (let loop
          ((i 0))
          (when (< i (vector-length files))
            (let ((file (vector-ref files i)))
              (cond
               ((not file)
                (vector-set! files i (%make-diff-file key path before (and before after)))
               ) ;
               ((equal? key (%diff-file-key file))
                (%diff-file-after-set! file (and (%diff-file-after file) before after))
               ) ;
               (else (loop (+ i 1)))
              ) ;cond
            ) ;let
          ) ;when
        ) ;let
      ) ;when
    ) ;define

    (define (%diff-compute before after with-text? jobs)
      (and (not (chan-closed? jobs))
        (string? before)
        (string? after)
        ;; Only derived display data is affected by a computation fault.
        (catch #t
          (lambda ()
            (and (eq? before (utf8-replace-invalid before))
              (eq? after (utf8-replace-invalid after))
              (%tool-diff before after with-text? (lambda () (chan-closed? jobs)))
            ) ;and
          ) ;lambda
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    ;; Optional results cannot wait for room in the UI event channel.
    (define (%diff-publish! events event)
      (catch #t (lambda () (chan-try-send! events event)) (lambda args #f))
    ) ;define

    (define (%diff-job! turn job events jobs)
      (let ((id (caddr job))
            (path (list-ref job 3))
            (key (list-ref job 4))
            (before (list-ref job 5))
            (after (list-ref job 6))
           ) ;
        (%diff-record-file! (%diff-turn-files turn) key path before after)
        (%diff-turn-count-set! turn (+ 1 (%diff-turn-count turn)))
        (let ((diff (%diff-compute before after #t jobs)))
          (%diff-publish! events
            (append (list 'diff_result (%diff-turn-id turn) id path)
              (or diff '(#f #f #f #f))
            ) ;append
          ) ;%diff-publish!
        ) ;let
      ) ;let
    ) ;define

    (define (%diff-summary files missed jobs)
      (and missed
        (let loop
          ((i 0) (entries '()))
          (if (= i (vector-length files))
            (reverse entries)
            (let* ((file (vector-ref files i))
                   (diff
                     (and file
                       (not (member (%diff-file-key file) missed))
                       (%diff-compute (%diff-file-before file) (%diff-file-after file) #f jobs)
                     ) ;and
                   ) ;diff
                  ) ;
              (loop (+ i 1)
                (if
                  (and diff (> (+ (cadr diff) (caddr diff)) 0))
                  (cons (list (%diff-file-path file) (cadr diff) (caddr diff)) entries)
                  entries
                ) ;if
              ) ;loop
            ) ;let*
          ) ;if
        ) ;let
      ) ;and
    ) ;define

    (define (%diff-finish-turn turn events jobs)
      (let ((control (or (%diff-turn-control turn) (chan-try-recv! (%diff-turn-done turn) #f))
            ) ;control
           ) ;
        (cond ((eof-object? control) #f)
              ((and (pair? control) (= (car control) (%diff-turn-count turn)))
               (%diff-publish! events
                 (list 'turn_diff_summary
                   (%diff-turn-id turn)
                   (or (%diff-summary (%diff-turn-files turn) (cdr control) jobs) '())
                 ) ;list
               ) ;%diff-publish!
               #f
              ) ;
              (else (%diff-turn-control-set! turn control) turn)
        ) ;cond
      ) ;let
    ) ;define

    (define (%pi-display-worker jobs events)
      (%display-loop jobs events (%worker-parser) (%worker-markdown-parser))
    ) ;define

    (define (%display-loop jobs events parse markdown)
      (let loop
        ((turn #f))
        (unless (chan-closed? jobs)
          (let* ((current (and turn (%diff-finish-turn turn events jobs)))
                 (job
                   (if (and current (not (%diff-turn-control current)))
                     (select ((chan-recv! jobs val) val)
                             ((chan-recv! (%diff-turn-done current) val)
                              (%diff-turn-control-set! current val)
                              #f
                             ) ;
                     ) ;select
                     (chan-recv! jobs)
                   ) ;if
                 ) ;job
                ) ;
            (cond ((or (eof-object? job) (chan-closed? jobs)) #f)
                  ((not job) (loop current))
                  ((eq? (car job) 'diff_job)
                   (let ((active
                           (if (and current (equal? (%diff-turn-id current) (cadr job)))
                             current
                             (begin
                               ;; FIFO jobs and a serial producer: the previous
                               ;; control is available by the first job of a new run.
                               (when current
                                 (%diff-finish-turn current events jobs)
                               ) ;when
                               (%make-diff-turn (cadr job) (list-ref job 7) (make-vector 16 #f) #f 0)
                             ) ;begin
                           ) ;if
                         ) ;active
                        ) ;
                     (%diff-job! active job events jobs)
                     (loop active)
                   ) ;let
                  ) ;
                  ((and (eq? (car job) 'markdown_job) (= (length job) 5))
                   (unless (chan-closed? (list-ref job 4))
                     (%diff-publish! (list-ref job 4)
                       (list (cadr job) (caddr job) (markdown (cadddr job)))
                     ) ;%diff-publish!
                   ) ;unless
                   (loop current)
                  ) ;
                  ((and (eq? (car job) 'diff_highlight_job) (= (length job) 5))
                   (let ((lines (parse (list-ref job 4))))
                     (unless (chan-closed? jobs)
                       (%diff-publish! events
                         (list 'diff_highlight_result (cadr job) (caddr job) (cadddr job) lines)
                       ) ;%diff-publish!
                     ) ;unless
                   ) ;let
                   (loop current)
                  ) ;
                  (else (loop current))
            ) ;cond
          ) ;let*
        ) ;unless
      ) ;let
    ) ;define
  ) ;begin
) ;define-library
