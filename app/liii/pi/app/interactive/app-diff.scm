;; Copyright (C) 2026 The Goldfish Scheme Authors
;; Licensed under the MIT License

(define-library (liii pi app interactive app-diff)
  (export %pi-app-handle-diff-event! %pi-app-apply-diff! %pi-app-settle-diff!
    %pi-app-reset-diff! %pi-app-current-diff-id
  ) ;export
  (import (scheme base)
    (liii string)
    (liii hash-table)
    (liii tui)
    (liii pi app interactive state)
    (liii pi app interactive renderers)
    (liii pi app interactive tool-diff)
    (liii pi app interactive views theme)
    (liii pi app interactive views tool-card)
    (liii pi app interactive status-card)
  ) ;import
  (begin
    (define-record-type <app-diff-run>
      (%make-app-diff-run id early settled? summary)
      %app-diff-run?
      (id %app-diff-run-id)
      (early %app-diff-run-early)
      (settled? %app-diff-run-settled? %app-diff-run-settled-set!)
      (summary %app-diff-run-summary %app-diff-run-summary-set!)
    ) ;define-record-type

    (define (%pi-app-current-diff-id app)
      (let ((run (%pi-app-diff-run app)))
        (and run (%app-diff-run-id run))
      ) ;let
    ) ;define

    (define (%pi-app-reset-diff! app)
      ;; Dispatch retires the old live index even if the optional run marker
      ;; is dropped by a saturated event channel.
      (%pi-app-tool-cards-set! app '())
      (%pi-app-diff-run-set! app #f)
    ) ;define

    (define (%pi-app-apply-diff! app id card)
      (let ((run (%pi-app-diff-run app)))
        (when run
          (let* ((early (%app-diff-run-early run)) (result (hash-table-ref early id)))
            (when (pair? result)
              (let ((applied (%tool-card-apply-diff! card (car result) (cadr result) (caddr result))
                    ) ;applied
                   ) ;
                (when applied
                  (hash-table-set! early id 'consumed)
                ) ;when
                (when (eq? applied 'changed)
                  (scroll-view-invalidate! (pi-app-scroll-view app))
                ) ;when
              ) ;let
            ) ;when
          ) ;let*
        ) ;when
      ) ;let
    ) ;define

    (define (%pi-app-show-diff-summary! app run)
      (let ((entries (%app-diff-run-summary run)))
        (when (and (%app-diff-run-settled? run) (list? entries))
          (%app-diff-run-summary-set! run 'shown)
          (unless (null? entries)
            (let ((box (make-container)))
              (container-add! box
                (make-status-card
                  (string-append %fg-title
                    "Turn changes"
                    %bold-reset
                    " "
                    (%tool-diff-counts (apply + (map cadr entries)) (apply + (map caddr entries)))
                  ) ;string-append
                ) ;make-status-card
              ) ;container-add!
              (for-each
                (lambda (entry)
                  (let ((path (%clean-tool-display-text (car entry))))
                    (container-add! box
                      (make-status-card (string-append %fg-accent
                                          (string-replace path "\n" " ")
                                          %fg-reset
                                          " "
                                          (%tool-diff-counts (cadr entry) (caddr entry))
                                        ) ;string-append
                      ) ;make-status-card
                    ) ;container-add!
                  ) ;let
                ) ;lambda
                entries
              ) ;for-each
              (container-add! (%pi-app-chat app) box)
              (scroll-view-invalidate! (pi-app-scroll-view app))
            ) ;let
          ) ;unless
        ) ;when
      ) ;let
    ) ;define

    (define (%pi-app-settle-diff! app)
      (let ((run (%pi-app-diff-run app)))
        (when run
          (%app-diff-run-settled-set! run #t)
          (%pi-app-show-diff-summary! app run)
        ) ;when
      ) ;let
    ) ;define

    (define (%diff-startable? event)
      (and (= (length event) 2) (exact-integer? (cadr event)) (> (cadr event) 0))
    ) ;define

    (define (%diff-line-count? n)
      (and (exact-integer? n) (<= 0 n %diff-lines-count-limit))
    ) ;define

    (define (%diff-summary-entry? entry)
      (and (list? entry)
        (= (length entry) 3)
        (string? (car entry))
        (%diff-line-count? (cadr entry))
        (%diff-line-count? (caddr entry))
        (> (+ (cadr entry) (caddr entry)) 0)
      ) ;and
    ) ;define

    (define (%diff-summary-entries? entries)
      (and (list? entries)
        (<= (length entries) 16)
        (let loop
          ((rest entries))
          (or (null? rest) (and (%diff-summary-entry? (car rest)) (loop (cdr rest))))
        ) ;let
      ) ;and
    ) ;define

    (define (%diff-result? event)
      (and (= (length event) 8)
        (string? (caddr event))
        (let ((text (list-ref event 4))
              (added (list-ref event 5))
              (removed (list-ref event 6))
             ) ;
          (or (and (not text) (not added) (not removed))
            (and (or (not text) (string? text))
              (%diff-line-count? added)
              (%diff-line-count? removed)
            ) ;and
          ) ;or
        ) ;let
      ) ;and
    ) ;define

    (define (%pi-app-handle-diff-event! app event)
      ;; Only internal events reach this boundary; ignore malformed payloads
      ;; rather than letting optional display work interrupt the event loop.
      (when (and (list? event) (pair? event) (pair? (cdr event)))
        (%pi-app-dispatch-diff! app event)
      ) ;when
    ) ;define

    (define (%pi-app-dispatch-diff! app event)
      (let ((id (cadr event)) (run (%pi-app-diff-run app)))
        (cond
         ((and (eq? (car event) 'run_started) (%diff-startable? event))
          ;; Agent events are ordered on their channel. A reused call ID
          ;; in a live run must not resolve to an earlier/history card.
          (%pi-app-tool-cards-set! app '())
          (%pi-app-diff-run-set! app (%make-app-diff-run id (make-hash-table) #f #f))
         ) ;
         ((and run (equal? id (%app-diff-run-id run)))
          (case (car event)
                ((diff_result)
                 (when (%diff-result? event)
                   (%pi-app-handle-diff-result! app event run)
                 ) ;when
                ) ;
                ((turn_diff_summary)
                 (when (and (not (%app-diff-run-summary run))
                         (= (length event) 3)
                         (%diff-summary-entries? (caddr event))
                       ) ;and
                   (%app-diff-run-summary-set! run (caddr event))
                   (%pi-app-show-diff-summary! app run)
                 ) ;when
                ) ;
          ) ;case
         ) ;
        ) ;cond
      ) ;let
    ) ;define
    (define (%pi-app-handle-diff-result! app event run)
      (let* ((call-id (caddr event))
             (early (%app-diff-run-early run))
             (card (assoc call-id (%pi-app-tool-cards app)))
            ) ;
        (unless (hash-table-ref early call-id)
          (hash-table-set! early
            call-id
            (list (list-ref event 4) (list-ref event 5) (list-ref event 6))
          ) ;hash-table-set!
          (when card
            (%pi-app-apply-diff! app call-id (cdr card))
          ) ;when
        ) ;unless
      ) ;let*
    ) ;define
  ) ;begin
) ;define-library
