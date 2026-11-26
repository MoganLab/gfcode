;; %pi-display-worker
;; 在同一个工作协程内依次产生纯文本 diff 和高亮结果。
;;
;; 语法
;; ----
;; (%pi-display-worker jobs events)
;;
;; 参数
;; ----
;; jobs 和 events 是有界通道。
;;
;; 返回值
;; ----
;; 忽略；结果按原文、高亮发送，汇总不依赖高亮。
;; Record cold/ready latency; no machine-dependent performance assertions.
(import (scheme base)
  (scheme time)
  (scheme write)
  (liii go)
  (liii check)
  (liii pi app interactive diff-worker)
) ;import
(check-set-mode! 'report-failed)

(define jobs (make-chan 16))

(define events (make-chan 16))

(define done (make-chan 1))

(define text (apply string-append (make-list 100 "修改 abcdefghijk\n")))

(define start (current-jiffy))
(go (%pi-display-worker jobs events))
(chan-send! jobs (list 'diff_job 1 "e" "p" "p" "" text done) 100)

(define plain (chan-recv! events 10000 #f))

(define plain-time (current-jiffy))
(check (car plain) => 'diff_result)
(chan-send! jobs (list 'diff_highlight_job 1 "e" 1 (list-ref plain 4)) 100)

(define result (chan-recv! events 10000 #f))

(define ready (current-jiffy))
(check (and result (car result)) => 'diff_highlight_result)
(check (and result (list? (list-ref result 4)) (length (list-ref result 4)))
  =>
  101
) ;check
(chan-send! done '(1) 100)
(check (chan-recv! events 10000 #f) => '(turn_diff_summary 1 (("p" 100 0))))
(display
  (list 'milliseconds-plain-highlight
    (inexact (/ (* 1000 (- plain-time start)) (jiffies-per-second)))
    (inexact (/ (* 1000 (- ready plain-time)) (jiffies-per-second)))
  ) ;list
) ;display
(newline)
(chan-close! jobs)

(check-report)
