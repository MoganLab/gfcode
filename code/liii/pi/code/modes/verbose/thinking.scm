;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code modes verbose thinking)
  (import (scheme base)
    (scheme write)
    (liii pi ai time)
    (liii pi code modes verbose state)
  ) ;import
  (export verbose-thinking-ping-due? %handle-thinking-start!
    %handle-thinking-delta! %handle-thinking-end!
  ) ;export
  (begin

    ;; 思考进度行间隔（毫秒）：正在思考中每 60s 提示一次
    (define %thinking-ping-interval-ms 60000)

    (define (verbose-thinking-ping-due? elapsed-ms)
      (>= elapsed-ms %thinking-ping-interval-ms)
    ) ;define

    (define (%format-elapsed-ms ms)
      (string-append (number->string (floor (/ ms 1000))) "s")
    ) ;define

    (define (%handle-thinking-start! turn-box port)
      (let ((tb (%thinking-box turn-box)))
        (when (vector? tb)
          (vector-set! tb 0 #t)
          (vector-set! tb 1 (pi-current-monotonic-millis))
          (vector-set! tb 2 (pi-current-monotonic-millis))
        ) ;when
      ) ;let
      (display "🧠 开始思考…\n" port)
    ) ;define

    (define (%handle-thinking-delta! turn-box port)
      (let ((tb (%thinking-box turn-box)))
        ;; 不显示具体思考内容；仅按间隔提示仍在思考
        (when (and (vector? tb) (vector-ref tb 0))
          (let* ((now (pi-current-monotonic-millis)) (since-last (- now (vector-ref tb 2))))
            (when (verbose-thinking-ping-due? since-last)
              (vector-set! tb 2 now)
              (let ((elapsed (- now (vector-ref tb 1))))
                (display (string-append "🧠 仍在思考…（已 "
                           (%format-elapsed-ms elapsed)
                           "）\n"
                         ) ;string-append
                  port
                ) ;display
              ) ;let
            ) ;when
          ) ;let*
        ) ;when
      ) ;let
    ) ;define

    (define (%handle-thinking-end! turn-box port)
      (let ((tb (%thinking-box turn-box)))
        (when (and (vector? tb) (vector-ref tb 0))
          (let ((elapsed (- (pi-current-monotonic-millis) (vector-ref tb 1))))
            (vector-set! tb 0 #f)
            (display (string-append "🧠 思考完成（用时 "
                       (%format-elapsed-ms elapsed)
                       "）\n"
                     ) ;string-append
              port
            ) ;display
          ) ;let
        ) ;when
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
