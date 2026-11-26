;; %pi-app-handle-diff-event! applies runtime display events without waiting.
;; (pi-app-poll-events! app) consumes the same events used by the real workers.
;; No return value is required; stale/duplicate results and failures are ignored.
(import (scheme base)
  (liii check)
  (liii go)
  (liii string)
  (liii tui)
  (liii pi agent queue)
  (liii pi app interactive app)
  (liii pi app interactive views tool-card)
  (liii pi app interactive state)
) ;import

(check-set-mode! 'report-failed)

(define app
  (make-pi-app
    :terminal     (make-virtual-terminal :width 80 :height 24)
    :handler      (lambda args #f)
    :bash-handler (lambda args (values "" 0))
  ) ;make-pi-app
) ;define

(define (emit . events)
  (for-each (lambda (ev) (chan-send! (pi-app-event-chan app) ev 100)) events)
  (pi-app-poll-events! app)
) ;define

(define (transcript)
  (string-join (map strip-ansi (pi-app-transcript-lines app)) "\n")
) ;define

(define (shows? text)
  (string-contains? (transcript) text)
) ;define

(define args '(("path" . "sample.txt")))

(define (start id)
  (list 'tool_execution_start id "write" args)
) ;define

(define (end id ok?)
  (list 'tool_execution_end
    id
    "write"
    args
    (not ok?)
    (if ok? "Saved!" "Write failed!")
  ) ;list
) ;define

(emit '(run_started 1)
  (start "early")
  '(diff_result 1 "early" "sample.txt" "+early" 1 0 1)
) ;emit
(check-false (shows? "+early"))
(emit (end "early" #t))
(check-true (shows? "+early"))
(check-true (shows? "sample.txt +1 -0"))
(emit '(diff_result 1 "early" "sample.txt" "+duplicate" 8 8 1)
  (start "late")
  (end "late" #t)
) ;emit
(check-true (shows? "Saved!"))
(check-false (shows? "+duplicate"))
(emit '(diff_result 1 "late" "sample.txt" "+late" 2 1 1)
  (start "error")
  (end "error" #f)
  '(diff_result 1 "error" "sample.txt" "+false-success" 2 1 1)
) ;emit
(check-true (shows? "+late"))
(check-true (shows? "Write failed!"))
(check-false (shows? "+false-success"))

(emit '(turn_diff_summary 1 (("sample.txt" 2 0))))
(check-false (shows? "Turn changes"))
(emit '(assistant_text "Final answer") '(agent_settled #f))
(check-true (shows? "Turn changes"))
(check-true
  (string-contains? (car (string-split (transcript) "Turn changes"))
    "Final answer"
  ) ;string-contains?
) ;check-true
(emit '(turn_diff_summary 1 (("duplicate-summary.txt" 2 1))))
(check-false (shows? "duplicate-summary.txt"))

;; Run 2 reuses a tool ID. Completion and another task can proceed without diff.
(emit '(run_started 2) (start "early") (end "early" #t) '(agent_settled #f))
(check-true (pi-queue-idle? (pi-app-queue app)))
(emit '(run_started 3)
  (start "early")
  '(diff_result 2 "early" "sample.txt" "+stale" 9 9 1)
  '(turn_diff_summary 2 (("stale-summary.txt" 9 9)))
  '(diff_result 3 "early" "sample.txt" "+fresh" 1 0 1)
  (end "early" #t)
  '(agent_settled #f)
) ;emit
(check-false (shows? "+stale"))
(check-false (shows? "stale-summary.txt"))
(check-true (shows? "+fresh"))
(emit '(turn_diff_summary 3 (("late-summary.txt" 1 0))))
(check-true (shows? "late-summary.txt +1 -0"))

;; Start-less completion also supports an early result.
(emit '(run_started 4)
  '(diff_result 4 "nostart" "sample.txt" "+nostart" 1 0 1)
  (end "nostart" #t)
) ;emit
(check-true (shows? "+nostart"))
(emit '(diff_result 4 "bad-payload")
  '(turn_diff_summary 4 (("not-a-count.txt" "1" 0)))
) ;emit
(emit '(agent_settled #f))
(check-false (shows? "not-a-count.txt"))

;; Keep the same card, invalidate its render cache, and reuse the existing
;; sanitation and Ctrl+O folding path for plain-text diff output.
(emit '(run_started 5) (start "fold") (end "fold" #t))
(let* ((card (cdr (assoc "fold" (%pi-app-tool-cards app))))
       (before (component-render card 80))
       (preview (string-append (apply string-append (make-list 12 "+line\n"))
                  "+\t\x1b;[33m最后一行\x1b;[0m"
                ) ;string-append
       ) ;preview
      ) ;
  (emit (list 'diff_result 5 "fold" "sample.txt" preview 13 0 1))
  (check
    (eq? card (cdr (assoc "fold" (%pi-app-tool-cards app))))
    =>
    #t
  ) ;check
  (check-false (eq? before (component-render card 80)))
  (check-true (shows? "ctrl+o to expand"))
  (check-false (shows? "最后一行"))
  (pi-app-toggle-tool-output! app)
  (check-true (shows? "+   最后一行"))
) ;let*

;; The actual queue dispatch, not just run_started, closes the previous turn.
(pi-app-submit! app "the next task")
(emit '(turn_diff_summary 5 (("after-dispatch.txt" 1 0))))
(check-false (shows? "after-dispatch.txt"))
(check-false (assoc "fold" (%pi-app-tool-cards app)))
;; If run_started was dropped, a reused ID still creates a new plain card.
(emit (start "fold") (end "fold" #t))
(check-true (shows? "Saved!"))
(check-true (shows? "+   最后一行"))
(check-report)
