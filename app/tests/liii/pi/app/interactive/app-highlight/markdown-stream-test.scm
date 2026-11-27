;; pi-app-poll-events! : app -> unspecified. A paused display worker must not
;; delay raw text, settlement or another card. Only latest matching rows apply.
;; 语法
;; ----
;; (pi-app-poll-events! app)
;; 参数
;; ----
;; app：虚拟终端上的交互应用。
;; 返回值
;; ----
;; 忽略；从通道和渲染行观察结果。
(import (scheme base)
  (scheme time)
  (scheme write)
  (liii check)
  (liii go)
  (liii tui)
  (liii string)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive views assistant)
  (liii pi app interactive views markdown)
) ;import
(check-set-mode! 'report-failed)

(define app
  (make-pi-app :terminal (make-virtual-terminal 80 24) :handler (lambda args #f))
) ;define

(define jobs (%pi-app-display-jobs app))

(define (send ev)
  (chan-send! (pi-app-event-chan app) ev 100)
) ;define

(define (poll)
  (pi-app-poll-events! app)
) ;define

(define (take-job)
  (chan-try-recv! jobs #f)
) ;define

(define parse (%worker-markdown-parser))

(define (reply! job)
  (chan-send! (list-ref job 4)
    (list (cadr job) (caddr job) (parse (cadddr job) (cadr job) (list-ref job 5)))
    100
  ) ;chan-send!
) ;define
(send '(assistant_text_delta "# 标题\n```scheme\n(define x "))
(poll)

(define card (pi-app-assistant-card app))

(define first (take-job))

(define start (current-jiffy))
;; Keep the first snapshot outstanding across eight separately rendered frames.
(do ((i 0 (+ i 1)))
  ((= i 8))
  (do ((j 0 (+ j 1)))
    ((= j 16))
    (send '(assistant_text_delta "1"))
  ) ;do
  (poll)
) ;do
(send '(assistant_text_delta ")\n```\n**结"))
(send '(assistant_text_delta "束**"))
(send '(agent_settled #f))
(poll)

(define ready (current-jiffy))
(check-false (pi-app-assistant-card app))
(check-false (take-job))

(define plain (component-render card 80))
(reply! first)
(poll)
;; The earlier result still owns a stable heading; it must not truncate
;; the raw suffix which arrived while the job was outstanding.

(define partial (component-render card 80))
(check-true (string-contains? (car partial) "\x1b;["))
(check (map strip-ansi partial) => plain)
(check (list-ref first 5) => #f)

(define last-job (take-job))
(check (cadddr last-job) => (assistant-card-text card))
(check (list-ref last-job 5) => #t)
(reply! last-job)
(do ((i 0 (+ i 1)))
  ((= i 12))
  (poll)
) ;do

(define colored (component-render card 80))
(check-true (string-contains? (car colored) "\x1b;["))
(check (map strip-ansi colored) => plain)
(check-true (eq? colored (component-render card 80)))
(check-true (> (length (component-render card 12)) (length colored)))
(poll)
(check-false (take-job))

(define (baseline-ms)
  (let* ((plain-app (make-pi-app :terminal (make-virtual-terminal 80 24) :handler (lambda args #f))
         ) ;plain-app
         (events (pi-app-event-chan plain-app))
        ) ;
    (chan-close! (%pi-app-display-jobs plain-app))
    (chan-send! events
      '(assistant_text_delta "# 标题\n```scheme\n(define x ")
      100
    ) ;chan-send!
    (pi-app-poll-events! plain-app)
    (let ((begin-time (current-jiffy)))
      (do ((i 0 (+ i 1)))
        ((= i 8))
        (do ((j 0 (+ j 1)))
          ((= j 16))
          (chan-send! events '(assistant_text_delta "1") 100)
        ) ;do
        (pi-app-poll-events! plain-app)
      ) ;do
      (chan-send! events '(assistant_text_delta ")\n```\n**结") 100)
      (chan-send! events '(assistant_text_delta "束**") 100)
      (chan-send! events '(agent_settled #f) 100)
      (pi-app-poll-events! plain-app)
      (* 1000.0 (/ (- (current-jiffy) begin-time) (jiffies-per-second)))
    ) ;let
  ) ;let*
) ;define
(display (list 'disabled-frames-ms (baseline-ms)))
(newline)
(display
  (list 'stream-frames-ms
    (* 1000.0 (/ (- ready start) (jiffies-per-second)))
    'deltas
    131
    'jobs
    2
  ) ;list
) ;display
(newline)

(check-report)
