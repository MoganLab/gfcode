;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive app-highlight)
  (export %pi-app-pump-highlight! %pi-app-handle-highlight!)
  (import (scheme base)
    (liii go)
    (liii tui)
    (liii pi app interactive state)
    (liii pi app interactive app-diff)
    (liii pi app interactive views highlight-view)
    (liii pi app interactive views tool-card)
    (liii pi app interactive views ansi-lines)
  ) ;import
  (begin
    (define (%pi-app-pump-highlight! app)
      (let ((id (%pi-app-current-diff-id app)) (jobs (%pi-app-display-jobs app)))
        (when (and id (not (chan-closed? jobs)))
          (let loop
            ((cards (%pi-app-tool-cards app)))
            (unless (null? cards)
              (let* ((entry (car cards)) (card (cdr entry)) (view (%tool-card-live-view card)))
                (cond
                 ((or (not view)
                    (not (eq? (%highlight-status view) 'pending))
                    (equal? (%highlight-requested view) (%highlight-revision view))
                  ) ;or
                  (loop (cdr cards))
                 ) ;
                 ((chan-try-send! jobs
                    (list 'diff_highlight_job
                      id
                      (car entry)
                      (%highlight-revision view)
                      (%tool-card-raw-diff card)
                    ) ;list
                  ) ;chan-try-send!
                  (%highlight-requested-set! view (%highlight-revision view))
                  (loop (cdr cards))
                 ) ;
                ) ;cond
              ) ;let*
            ) ;unless
          ) ;let
        ) ;when
      ) ;let
    ) ;define
    (define (%pi-app-handle-highlight! app event)
      (when
        (and (list? event)
          (= (length event) 5)
          (exact-integer? (cadr event))
          (equal? (%pi-app-current-diff-id app) (cadr event))
          (string? (caddr event))
          (not (chan-closed? (%pi-app-display-jobs app)))
        ) ;and
        (let* ((entry (assoc (caddr event) (%pi-app-tool-cards app)))
               (view (and entry (%tool-card-live-view (cdr entry))))
               (rev (cadddr event))
               (lines (list-ref event 4))
              ) ;
          (when (and view
                  (eq? (%highlight-status view) 'pending)
                  (exact-integer? rev)
                  (equal? rev (%highlight-requested view))
                  (= rev (%highlight-revision view))
                  (or (not lines) (%diff-rows? lines))
                ) ;and
            (%highlight-finish! view lines)
            (scroll-view-invalidate! (pi-app-scroll-view app))
          ) ;when
        ) ;let*
      ) ;when
    ) ;define
  ) ;begin
) ;define-library
