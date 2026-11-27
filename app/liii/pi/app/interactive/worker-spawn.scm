;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; go-apply/source 与 go 使用相同的 worker 前导 import，但会把前导失败
;; 通过结果 channel 返回主线程。普通 go 在这个阶段的错误只能写 stderr，
;; worker 函数体内的 catch 没有机会执行。
(define-library (liii pi app interactive worker-spawn)
  (import (scheme base) (liii go) (liii string) (liii error) (liii pi ai log))
  (export %pi-worker-spawn! pi-worker-spawn-poll-errors!)
  (begin

    (define *worker-spawn-results* '())

    (define (%pi-worker-spawn! name fn . args)
      (let ((result-ch (make-chan 1)))
        (set! *worker-spawn-results*
          (append *worker-spawn-results* (list (cons name result-ch)))
        ) ;set!
        (go-apply/source (procedure-source fn) (rootlet) args result-ch)
      ) ;let
    ) ;define

    (define (%worker-spawn-error-text tag args)
      (catch #t
        (lambda () (catch-error->string tag args))
        (lambda _ (object->string (cons tag args)))
      ) ;catch
    ) ;define

    (define (%log-worker-spawn-error! name result)
      (let ((tag (cadr result)) (args (if (pair? (cddr result)) (caddr result) '())))
        (catch #t
          (lambda ()
            (pi-log-error! (string-append "worker-error name="
                             name
                             " type="
                             (object->string tag)
                             " "
                             (%worker-spawn-error-text tag args)
                           ) ;string-append
            ) ;pi-log-error!
          ) ;lambda
          (lambda _ #f)
        ) ;catch
      ) ;let
    ) ;define

    ;; 在 TUI 主线程轮询。只消费已经完成的 worker 结果；长期运行的
    ;; worker 不会被等待或阻塞。前导 import 失败也会得到一个 error 结果。
    (define (pi-worker-spawn-poll-errors!)
      (let loop
        ((pending *worker-spawn-results*) (running '()))
        (if (null? pending)
          (set! *worker-spawn-results* (reverse running))
          (let* ((entry (car pending))
                 (name (car entry))
                 (result (chan-try-recv! (cdr entry) #f))
                ) ;
            (cond ((not result) (loop (cdr pending) (cons entry running)))
                  ((and (pair? result) (eq? (car result) 'error))
                   (%log-worker-spawn-error! name result)
                   (loop (cdr pending) running)
                  ) ;
                  (else (loop (cdr pending) running))
            ) ;cond
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
