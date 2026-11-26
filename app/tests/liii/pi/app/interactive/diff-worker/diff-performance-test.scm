;; %diff-performance: measure bounded capture and background diff separately.
;; This test takes no arguments. A gated display worker must not block the tool,
;; queue settlement, or the next dispatch; no timing threshold is machine-specific.
(import (scheme base)
  (scheme file)
  (scheme time)
  (scheme write)
  (liii check)
  (liii go)
  (liii path)
  (liii tempfile)
  (liii tui)
  (liii pi ai tools result)
  (liii pi agent queue)
  (liii pi code core tools)
  (liii pi app interactive app)
  (liii pi app interactive diff-capture)
  (liii pi app interactive diff-worker)
) ;import

(check-set-mode! 'report-failed)

(define (record-diff-time jobs events elapsed gate)
  (when (eq? (chan-recv! gate 3000 #f) 'start)
    (let ((t0 (monotonic-nanosecond)))
      (%pi-display-worker jobs events)
      (chan-try-send! elapsed (- (monotonic-nanosecond) t0))
    ) ;let
  ) ;when
) ;define

(define (lines line n)
  (apply string-append (make-list n line))
) ;define

(define (measure label thunk n)
  (let ((t0 (monotonic-nanosecond)))
    (do ((i 0 (+ i 1)))
      ((= i n))
      (thunk)
    ) ;do
    (display label)
    (display (/ (- (monotonic-nanosecond) t0) (* 1000000.0 n)))
    (display " ms\n")
  ) ;let
) ;define

(let* ((tmp (make-temp-dir "gf-pi-diff-perf-"))
       (file (path->string (path-join tmp "perf.txt")))
       (small "first\nsecond\n")
       (before (lines "before line 1345\n" 450))
       (after (lines "after line 1345\n" 450))
       (jobs (make-chan 16))
       (results (make-chan 4))
       (gate (make-chan 1))
       (elapsed (make-chan 1))
       (dispatched #f)
       (app (make-pi-app
              :terminal     (make-virtual-terminal 100 30)
              :handler      (lambda (_ msg) (set! dispatched msg))
              :bash-handler (lambda args (values "" 0))
            ) ;make-pi-app
       ) ;app
       (events (pi-app-event-chan app))
       (queue (pi-app-queue app))
       (run (%pi-make-diff-capture 1 jobs events))
       (emit
         (%pi-diff-emit run
           (lambda (kind . args) (chan-try-send! events (cons kind args)))
         ) ;%pi-diff-emit
       ) ;emit
       (execute (%pi-diff-executor run execute-tool-call))
       (args `(("path" . ,file) ("content" . ,after)))
      ) ;
  (go (record-diff-time jobs results elapsed gate))
  (dynamic-wind (lambda () #t)
    (lambda ()
      (path-write-text file small)
      (measure "bounded snapshot, 13 bytes (mean of 40): "
        (lambda () (%diff-read-snapshot file #f))
        40
      ) ;measure
      (path-write-text file before)
      (measure "bounded snapshot, 450 lines (mean of 20): "
        (lambda () (%diff-read-snapshot file #f))
        20
      ) ;measure
      (pi-queue-enqueue! queue "running")
      (check (pi-queue-dequeue-next! queue) => "running")
      (chan-try-send! events '(run_started 1))
      (emit 'tool_execution_start "write-perf" "write" args)
      (let ((res (execute "write" args)))
        (check-false (pi-tool-result-is-error res))
        (emit 'tool_execution_end "write-perf" "write" args #f res)
      ) ;let
      (emit 'assistant_text "Final reply")
      (emit 'agent_settled #f)
      (%pi-diff-finish! run)
      (pi-app-poll-events! app)
      (check-true (pi-queue-idle? queue))
      (check (path-read-text file) => after)
      (pi-app-submit! app "next run need not wait")
      (check dispatched => "next run need not wait")
      (check-true (pi-queue-idle? queue))
      (check (chan-try-recv! results #f) => #f)
      (chan-try-send! gate 'start)
      (let* ((t0 (monotonic-nanosecond)) (ev (chan-recv! results 3000 #f)))
        (check (and ev (list-tail ev 4)) => '(#f 450 450 1))
        (display "worker start to single-card result, 450x450: ")
        (display (/ (- (monotonic-nanosecond) t0) 1000000.0))
        (display " ms\n")
      ) ;let*
      (check (chan-recv! results 3000 #f)
        =>
        (list 'turn_diff_summary 1 (list (list file 450 450)))
      ) ;check
      (chan-close! jobs)
      (check-true (number? (chan-recv! elapsed 3000 #f)))
    ) ;lambda
    (lambda ()
      (chan-close! gate)
      (chan-close! jobs)
      (chan-close! results)
      (chan-close! elapsed)
      (when (file-exists? file)
        (delete-file file)
      ) ;when
      (path-rmdir tmp)
    ) ;lambda
  ) ;dynamic-wind
) ;let*

(check-report)
