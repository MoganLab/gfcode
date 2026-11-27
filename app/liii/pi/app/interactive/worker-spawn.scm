;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; worker 启动兼容层：
;; - 新 Goldfish（go-result / go-apply/source 把前导 import 失败回传
;;   (error tag args)，goldfish 分支 da/1415/go-prelude-error-result）：
;;   用 go-apply/source 启动并经结果 channel 把前导失败写入 pi 日志。
;; - 旧 Goldfish（前导失败只写 stderr，结果 channel 永远收不到消息）：
;;   回退普通 go，保持既有行为，不阻塞等待。
;; 能力探测：注册临时库后删源并从活动库表摘除，使 worker 前导真的
;; 重放该 import 而失败（主会话已命中缓存不受影响）：
;; 新实现回 (error ...)，旧实现只写 stderr、超时收不到 → 回退普通 go。
;; 探测在首个 worker 启动前执行，此时尚未加载任何扩展，不污染真实 worker。
(define-library (liii pi app interactive worker-spawn)
  (import (scheme base)
    (liii go)
    (liii string)
    (liii error)
    (liii path)
    (liii shutil)
    (liii tempfile)
    (liii hash-table)
    (liii pi ai log)
  ) ;import
  (export %pi-worker-spawn! pi-worker-spawn-poll-errors!)
  (begin

    (define *worker-spawn-results* '())

    ;; #f 未探测；#t 结果协议可用；'legacy 旧实现回退普通 go
    (define *spawn-result-protocol* #f)

    (define (%spawn-probe-worker)
      #t
    ) ;define

    (define (%probe-result-protocol)
      (catch #t
        (lambda ()
          (let* ((base (make-temp-dir "gf-pi-worker-spawn-probe-" ""))
                 (dir (path-join (path base) "gfcode"))
                 (file (path-join dir "probe.scm"))
                 (saved-load-path *load-path*)
                 (probe-ch (make-chan 1))
                ) ;
            (path-mkdir dir :parents #t :exist-ok #t)
            (path-write-text file
              "(define-library (gfcode spawn-probe) (import (scheme base)) (export ok) (begin (define ok #t)))"
            ) ;path-write-text
            (set! *load-path* (cons (path->string base) *load-path*))
            (load (path->string file))
            (eval '(import (gfcode spawn-probe)) (rootlet))
            (rmtree (path->string base) #t)
            (hash-table-delete! *r7rs-libraries* '(gfcode spawn-probe))
            (go-apply/source (procedure-source %spawn-probe-worker) (rootlet) '() probe-ch)
            (let ((result (chan-recv! probe-ch 5000 #f)))
              (set! *load-path* saved-load-path)
              (if (and (pair? result) (eq? (car result) 'error)) #t 'legacy)
            ) ;let
          ) ;let*
        ) ;lambda
        (lambda _ 'legacy)
      ) ;catch
    ) ;define

    (define (%spawn-result-protocol?)
      (when (not *spawn-result-protocol*)
        (set! *spawn-result-protocol* (%probe-result-protocol))
      ) ;when
      (eq? *spawn-result-protocol* #t)
    ) ;define

    (define (%pi-worker-spawn! name fn . args)
      (if (%spawn-result-protocol?)
        (let ((result-ch (make-chan 1)))
          (set! *worker-spawn-results*
            (append *worker-spawn-results* (list (cons name result-ch)))
          ) ;set!
          (go-apply/source (procedure-source fn) (rootlet) args result-ch)
        ) ;let
        (apply go-call fn args)
      ) ;if
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
