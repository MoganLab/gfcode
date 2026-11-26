;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive app-markdown)
  (export %markdown-reset! %markdown-dirty! %markdown-pump!)
  (import (scheme base)
    (liii go)
    (liii tui)
    (only (liii tui component) component-data)
    (liii pi app interactive state)
    (liii pi app interactive views assistant)
    (liii pi app interactive views markdown)
  ) ;import
  (begin
    ;; One in-flight snapshot per app. The private reply slot cannot be lost
    ;; to a full agent event channel. Replacing this record detaches old jobs.
    (define-record-type <markdown-work>
      (make-work history live active reply)
      work?
      (history history history-set!)
      (live live live-set!)
      (active active active-set!)
      (reply reply)
    ) ;define-record-type
    (define (%markdown-reset! app cards)
      (when (%pi-app-markdown app)
        (chan-close! (reply (%pi-app-markdown app)))
      ) ;when
      (%pi-app-markdown-set! app (make-work cards '() #f (make-chan 1)))
    ) ;define
    (define (%markdown-dirty! app card)
      (unless (%pi-app-markdown app)
        (%markdown-reset! app '())
      ) ;unless
      (let* ((w (%pi-app-markdown app)) (pending (live w)))
        (unless (memq card pending)
          ;; Retain card references, not copies of each delta. On overload
          ;; omit the oldest optional live decoration, never the text itself.
          (live-set! w
            (cons card
              (if (< (length pending) 16) pending (reverse (cdr (reverse pending))))
            ) ;cons
          ) ;live-set!
        ) ;unless
      ) ;let*
    ) ;define
    (define (eligible? card)
      (and (assistant-card-component? card)
        (not (%assistant-ready? (component-data card)))
        (<= (string-length (assistant-card-text card)) %markdown-max-bytes)
      ) ;and
    ) ;define
    (define (submit! jobs w card)
      (let ((st (component-data card)))
        (and (chan-try-send! jobs
               (list 'markdown_job
                 (%assistant-id st)
                 (%assistant-revision st)
                 (assistant-card-text card)
                 (reply w)
               ) ;list
             ) ;chan-try-send!
          (begin
            (active-set! w st)
            #t
          ) ;begin
        ) ;and
      ) ;let
    ) ;define
    (define (%markdown-pump! app)
      (let ((w (%pi-app-markdown app)) (jobs (%pi-app-display-jobs app)))
        (and w
          (not (chan-closed? jobs))
          (let* ((st (active w))
                 (res (and st (chan-try-recv! (reply w) #f)))
                 (changed? (and res
                             (= (car res) (%assistant-id st))
                             (%assistant-finish! st (cadr res) (caddr res))
                           ) ;and
                 ) ;changed?
                ) ;
            (when res
              (active-set! w #f)
            ) ;when
            ;; At most one result applied and one snapshot issued per UI poll.
            ;; Skip at most 16 non-assistant history cards in a poll.
            (let loop
              ((budget 16))
              (when (and (> budget 0) (not (active w)))
                (let* ((live? (pair? (live w))) (rest (if live? (live w) (history w))))
                  (when
                    (and (pair? rest) (or (not (eligible? (car rest))) (submit! jobs w (car rest))))
                    ((if live? live-set! history-set!) w (cdr rest))
                    (loop (- budget 1))
                  ) ;when
                ) ;let*
              ) ;when
            ) ;let
            (when changed?
              (scroll-view-invalidate! (pi-app-scroll-view app))
            ) ;when
            changed?
          ) ;let*
        ) ;and
      ) ;let
    ) ;define
  ) ;begin
) ;define-library
