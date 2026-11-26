;; %pi-display-worker (jobs events) consumes serialized diff jobs in a go
;; session and sends runtime diff_result and turn_diff_summary events. Unavailable
;; snapshots/budget overflow produce skipped results; no file I/O is performed.
(import (scheme base)
  (liii check)
  (only (liii base) byte-vector->string)
  (liii go)
  (liii string)
  (liii pi app interactive diff-worker)
) ;import

(check-set-mode! 'report-failed)

(define jobs (make-chan 16))

(define events (make-chan 16))

(define (send id call path key before after done)
  (check-true (chan-send! jobs (list 'diff_job id call path key before after done) 100)
  ) ;check-true
) ;define

(define (next-event)
  (chan-recv! events 3000 'timeout)
) ;define

;; Queue the snapshots first, but do not signal completion yet. Tools can
;; finish and the next run can be queued without waiting for these results.
(let ((first (make-chan 1))
      (second (make-chan 1))
      (large-a (apply string-append (make-list 1000 "old\n")))
      (large-b (apply string-append (make-list 1000 "new\n")))
     ) ;
  (send 1 "a" "same.txt" "/same.txt" "one\n" "two\n" first)
  (send 1 "b" "./same.txt" "/same.txt" "two\n" "one\n" first)
  (send 1 "c" "net.txt" "/net.txt" "a\n" "a\nb\n" first)
  (send 1 "d" "net.txt" "/net.txt" "a\nb\n" "b\n" first)
  (send 1 "e" "missed.txt" "/missed.txt" "a\n" "b\n" first)
  (send 1 "f" "oversized.txt" "/oversized.txt" large-a large-b first)
  (send 1 "g" "incomplete.txt" "/incomplete.txt" #f #f first)
  (send 1 "h" "incomplete.txt" "/incomplete.txt" "a\n" "b\n" first)
  (send 2 "a" "next.txt" "/next.txt" "" "end\n" second)
  (check (chan-try-recv! events #f) => #f)
  (chan-send! first '(8 "/missed.txt") 100)
  (chan-close! first)
  (chan-send! second '(1) 100)
  (chan-close! second)
  (go (%pi-display-worker jobs events))
  (check (next-event)
    =>
    '(diff_result 1 "a" "same.txt" "@@ -1,1 +1,1 @@\n-one\n+two" 1 1 1)
  ) ;check
  (check (next-event)
    =>
    '(diff_result 1 "b" "./same.txt" "@@ -1,1 +1,1 @@\n-two\n+one" 1 1 1)
  ) ;check
  (do ((i 0 (+ i 1)))
    ((= i 3))
    (check (car (next-event)) => 'diff_result)
  ) ;do
  (check (next-event) => '(diff_result 1 "f" "oversized.txt" #f #f #f #f))
  (check (next-event) => '(diff_result 1 "g" "incomplete.txt" #f #f #f #f))
  (check (car (next-event)) => 'diff_result)
  (check (next-event) => '(turn_diff_summary 1 (("net.txt" 1 1))))
  (check (next-event)
    =>
    '(diff_result 2 "a" "next.txt" "@@ -0,0 +1,1 @@\n+end" 1 0 1)
  ) ;check
  (check (next-event) => '(turn_diff_summary 2 (("next.txt" 1 0))))
) ;let
(let ((third (make-chan 1)))
  (send 3
    "invalid"
    "binary.dat"
    "/binary.dat"
    (byte-vector->string (bytevector 255))
    "text\n"
    third
  ) ;send
  (chan-send! third '(1) 100)
  (chan-close! third)
  (check (next-event) => '(diff_result 3 "invalid" "binary.dat" #f #f #f #f))
  (check (next-event) => '(turn_diff_summary 3 ()))
) ;let
(chan-close! jobs)
(chan-close! events)

(check-report)
