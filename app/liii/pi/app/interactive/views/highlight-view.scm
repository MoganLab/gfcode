;; Copyright (C) 2026 The Goldfish Scheme Authors. MIT License.
(define-library (liii pi app interactive views highlight-view)
  (export %new-highlight-view %highlight-revision %highlight-status
    %highlight-requested %highlight-requested-set! %highlight-lines
    %highlight-reset! %highlight-finish!
  ) ;export
  (import (scheme base))
  (begin
    (define-record-type <highlight-view>
      (make-view revision status requested lines)
      view?
      (revision %highlight-revision set-revision!)
      (status %highlight-status set-status!)
      (requested %highlight-requested %highlight-requested-set!)
      (lines %highlight-lines set-lines!)
    ) ;define-record-type
    (define (%new-highlight-view)
      (make-view 0 #f #f #f)
    ) ;define
    (define (%highlight-reset! view)
      (set-revision! view (+ 1 (%highlight-revision view)))
      (%highlight-requested-set! view #f)
      (set-lines! view #f)
      (set-status! view 'pending)
    ) ;define
    (define (%highlight-finish! view lines)
      (set-lines! view lines)
      (set-status! view (if lines 'ready 'skipped))
    ) ;define
  ) ;begin
) ;define-library
