;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive app-markdown)
  (export %markdown-reset! %markdown-dirty! %markdown-pump!
    %markdown-block-display?
  ) ;export
  (import (scheme base)
    (liii go)
    (liii tui)
    (only (liii tui component) component-data)
    (liii pi code utils shell)
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
          ;; A final block is no longer optional decoration: dropping its
          ;; card here would leave part of the response permanently hidden.
          (live-set! w (cons card pending))
        ) ;unless
      ) ;let*
    ) ;define
    (define (%markdown-block-display? app)
      (and (not (%pi-app-handler app))
        (not (chan-closed? (%pi-app-display-jobs app)))
      ) ;and
    ) ;define

    (define (eligible? card)
      (and (assistant-card-component? card)
        (not (%assistant-ready? (component-data card)))
      ) ;and
    ) ;define
    (define (submit! jobs w card live?)
      (let ((st (component-data card)))
        (and (chan-try-send! jobs
               (list 'markdown_job
                 (%assistant-id st)
                 (%assistant-revision st)
                 (assistant-card-text card)
                 (reply w)
                 (not live?)
               ) ;list
             ) ;chan-try-send!
          (begin
            (active-set! w
              (list st
                (%assistant-revision st)
                (sanitize-display-text (assistant-card-text card))
                #f
              ) ;list
            ) ;active-set!
            #t
          ) ;begin
        ) ;and
      ) ;let
    ) ;define
    (define (%markdown-pump! app)
      (let ((w (%pi-app-markdown app)) (jobs (%pi-app-display-jobs app)))
        (and w
          (not (chan-closed? jobs))
          (let* ((active-job (active w))
                 (st (and active-job (car active-job)))
                 (received (and st (not (list-ref active-job 3)) (chan-try-recv! (reply w) #f)))
                 (res (or (and active-job (list-ref active-job 3)) received))
                 (blocks (and res
                           (= (car res) (%assistant-id st))
                           (= (cadr res) (cadr active-job))
                           (caddr res)
                         ) ;and
                 ) ;blocks
                 (changed?
                   (cond ((pair? blocks)
                          (apply %assistant-prefix! st (cadr res) (caddr active-job) (car blocks))
                         ) ;
                         ((and res (not blocks)) (%assistant-finish! st (cadr res) #f))
                         (else #f)
                   ) ;cond
                 ) ;changed?
                ) ;
            (when res
              (if (and (pair? blocks) (pair? (cdr blocks)))
                (active-set! w
                  (list st
                    (cadr active-job)
                    (caddr active-job)
                    (list (car res) (cadr res) (cdr blocks))
                  ) ;list
                ) ;active-set!
                (active-set! w #f)
              ) ;if
            ) ;when
            ;; At most one result applied and one snapshot issued per UI poll.
            ;; Skip at most 16 non-assistant history cards in a poll.
            (let loop
              ((budget 16))
              (when (and (> budget 0) (not (active w)))
                (let* ((live? (pair? (live w))) (rest (if live? (live w) (history w))))
                  (when
                    (and (pair? rest)
                      (or (not (eligible? (car rest)))
                        (submit! jobs w (car rest) (eq? (car rest) (pi-app-assistant-card app)))
                      ) ;or
                    ) ;and
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
