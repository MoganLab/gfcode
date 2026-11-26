;; Copyright (C) 2026 The Goldfish Scheme Authors
;; Licensed under the MIT License

(define-library (liii pi app interactive diff-capture)
  (export %pi-make-diff-capture %pi-diff-executor %pi-diff-emit %pi-diff-finish!
    %pi-diff-config %diff-capture-id %diff-capture-done %diff-capture-events
    %diff-capture-jobs %diff-capture-call %diff-capture-call-set!
    %diff-capture-count %diff-capture-count-set! %diff-capture-misses
    %diff-capture-misses-set! %diff-tool? %diff-read-snapshot %pi-diff-start
    %diff-without-nul? %diff-text-snapshot %diff-cwd %diff-try-send!
    %diff-enqueue! %pi-with-turn-diff %diff-written-size? %diff-valid-path?
    %diff-read-bounded
  ) ;export
  (import (scheme base)
    (scheme file)
    (only (liii base) byte-vector->string)
    (liii go)
    (liii os)
    (liii path stat)
    (liii pi ai config runtime)
    (liii pi ai tools result)
    (liii pi code core tools read)
    (liii pi app interactive tool-diff)
  ) ;import
  (begin
    (define-record-type <diff-capture>
      (%make-diff-capture id jobs events done call count misses)
      %diff-capture?
      (id %diff-capture-id)
      (jobs %diff-capture-jobs)
      (events %diff-capture-events)
      (done %diff-capture-done)
      (call %diff-capture-call %diff-capture-call-set!)
      (count %diff-capture-count %diff-capture-count-set!)
      (misses %diff-capture-misses %diff-capture-misses-set!)
    ) ;define-record-type

    (define (%pi-make-diff-capture id jobs events)
      (%make-diff-capture id jobs events (make-chan 1) #f 0 '())
    ) ;define

    (define (%diff-tool? name)
      (or (equal? name "edit") (equal? name "write"))
    ) ;define

    (define (%diff-without-nul? text)
      (let ((size (string-length text)))
        (let loop
          ((i 0))
          (or (= i size) (and (not (char=? (string-ref text i) #\nul)) (loop (+ i 1))))
        ) ;let
      ) ;let
    ) ;define

    (define (%diff-text-snapshot text)
      (and (string? text)
        (<= (string-length text) %diff-snapshot-bytes)
        (%diff-without-nul? text)
        text
      ) ;and
    ) ;define

    (define (%diff-read-bounded absolute expected)
      ;; On Windows, use a binary port so CRT text mode cannot translate CRLF.
      ;; On POSIX a raw read-string is a single fread rather than a Scheme byte loop.
      (let* ((binary? (os-windows?))
             (port (if binary? (open-binary-input-file absolute) (open-input-file absolute)))
            ) ;
        (dynamic-wind (lambda () #t)
          (lambda ()
            (let* ((limit (+ expected 1))
                   (raw (if binary? (read-bytevector limit port) (read-string limit port)))
                   (text (if (bytevector? raw) (byte-vector->string raw) raw))
                  ) ;
              (cond ((eof-object? text) (and (zero? expected) ""))
                    ((= (string-length text) expected) (%diff-text-snapshot text))
                    (else #f)
              ) ;cond
            ) ;let*
          ) ;lambda
          (lambda () (close-input-port port))
        ) ;dynamic-wind
      ) ;let*
    ) ;define

    (define (%diff-read-snapshot absolute missing-ok?)
      (catch 'file-not-found-error
        (lambda ()
          (let ((st (path-stat absolute)))
            (and (path-stat-file? st)
              (<= (path-stat-size st) %diff-snapshot-bytes)
              (%diff-read-bounded absolute (path-stat-size st))
            ) ;and
          ) ;let
        ) ;lambda
        (lambda args (and missing-ok? ""))
      ) ;catch
    ) ;define

    (define (%diff-cwd opts)
      (let loop
        ((rest opts))
        (cond ((not (pair? rest)) (getcwd))
              ((not (pair? (cdr rest))) (getcwd))
              ((eq? (car rest) :cwd) (cadr rest))
              (else (loop (cddr rest)))
        ) ;cond
      ) ;let
    ) ;define

    ;; Never wait to enqueue optional display data. Closed channels on shutdown
    ;; and optional snapshot errors must not log file contents or fail the tool.
    (define (%diff-try-send! ch message)
      (and ch (catch #t (lambda () (chan-try-send! ch message)) (lambda args #f)))
    ) ;define

    (define (%diff-enqueue! run id path absolute before after)
      (if
        (and absolute
          (%diff-try-send! (%diff-capture-jobs run)
            (list 'diff_job
              (%diff-capture-id run)
              id
              path
              absolute
              before
              after
              (%diff-capture-done run)
            ) ;list
          ) ;%diff-try-send!
        ) ;and
        (%diff-capture-count-set! run (+ 1 (%diff-capture-count run)))
        (let ((misses (%diff-capture-misses run)))
          ;; Remember dropped paths so an earlier snapshot cannot produce a
          ;; partial net count. If even this list overflows, omit the summary.
          (when misses
            (%diff-capture-misses-set! run
              (cond ((not absolute) #f)
                    ((member absolute misses) misses)
                    ((< (length misses) 16) (cons absolute misses))
                    (else #f)
              ) ;cond
            ) ;%diff-capture-misses-set!
          ) ;when
          (%diff-try-send! (%diff-capture-events run)
            (list 'diff_result (%diff-capture-id run) id path #f #f #f #f)
          ) ;%diff-try-send!
        ) ;let
      ) ;if
    ) ;define

    (define (%diff-valid-path? p)
      (and (string? p) (<= 1 (string-length p) 4096) (%diff-without-nul? p))
    ) ;define

    (define (%diff-written-size? absolute text)
      ;; write's original result can report success even when the filesystem
      ;; rejects a write. Check metadata without re-reading the content.
      (and text
        (let ((st (path-stat absolute)))
          (and (path-stat-file? st) (= (path-stat-size st) (string-length text)))
        ) ;let
      ) ;and
    ) ;define

    (define (%pi-diff-executor run execute)
      (lambda (name args . opts)
        (let ((call (%diff-capture-call run)))
          (if
            (not (and call (equal? (cdr call) name)))
            (apply execute name args opts)
            (let ((absolute #f)
                  (display-path #f)
                  (before #f)
                  (write-after #f)
                  (write? (equal? name "write"))
                 ) ;
              (catch #t
                (lambda ()
                  (let ((p (pi-arg-ref args "path")))
                    (when (%diff-valid-path? p)
                      (set! display-path p)
                      (set! absolute (pi-resolve-path p (%diff-cwd opts)))
                      (when (> (string-length absolute) 4096)
                        (set! absolute #f)
                      ) ;when
                      (when write?
                        (set! write-after (%diff-text-snapshot (pi-arg-ref args "content")))
                      ) ;when
                      (when (and absolute (or (not write?) write-after))
                        (set! before (%diff-read-snapshot absolute write?))
                      ) ;when
                    ) ;when
                  ) ;let
                ) ;lambda
                (lambda args #f)
              ) ;catch
              ;; Keep the originals outside the observation catches: execute
              ;; once, propagate its exceptions, and return its exact result.
              (let ((result (apply execute name args opts)))
                (when (and (pi-tool-result? result) (not (pi-tool-result-is-error result)))
                  (let ((after
                          (and before
                            (catch #t
                              (lambda ()
                                (if write?
                                  (and (%diff-written-size? absolute write-after) write-after)
                                  (%diff-read-snapshot absolute #f)
                                ) ;if
                              ) ;lambda
                              (lambda args #f)
                            ) ;catch
                          ) ;and
                        ) ;after
                       ) ;
                    (catch #t
                      (lambda () (%diff-enqueue! run (car call) display-path absolute before after))
                      (lambda args #f)
                    ) ;catch
                  ) ;let
                ) ;when
                result
              ) ;let
            ) ;let
          ) ;if
        ) ;let
      ) ;lambda
    ) ;define

    (define (%pi-diff-config run cfg)
      (let ((execute (and run (pi-cfg-ref cfg 'execute-tool-call))))
        (if (procedure? execute)
          (pi-cfg-merge cfg
            (list (cons 'execute-tool-call (%pi-diff-executor run execute)))
          ) ;pi-cfg-merge
          cfg
        ) ;if
      ) ;let
    ) ;define

    ;; This is an agent-worker-local observer; the existing make-tui-emit and
    ;; tool/extension event contracts do not change. Tools execute serially.
    (define (%pi-diff-emit run emit)
      (lambda (kind . args)
        (case kind
         ((tool_execution_start)
          (let ((id (car args)) (name (cadr args)))
            (%diff-capture-call-set! run
              (and (%diff-tool? name) (string? id) (cons id name))
            ) ;%diff-capture-call-set!
          ) ;let
         ) ;
         ((tool_execution_end) (%diff-capture-call-set! run #f))
        ) ;case
        (apply emit kind args)
      ) ;lambda
    ) ;define

    (define (%pi-diff-start run emit)
      ;; Optional events must not add backpressure to the agent. If the start
      ;; marker cannot be sent, disable capture for this run rather than orphaning results.
      (if
        (and run
          (%diff-try-send! (%diff-capture-events run)
            (list 'run_started (%diff-capture-id run))
          ) ;%diff-try-send!
        ) ;and
        (%pi-diff-emit run emit)
        emit
      ) ;if
    ) ;define

    (define (%pi-diff-finish! run)
      ;; A private one-slot control channel cannot be full on first finish,
      ;; and doesn't compete for space with snapshots in the shared job queue.
      (%diff-try-send! (%diff-capture-done run)
        (cons (%diff-capture-count run) (%diff-capture-misses run))
      ) ;%diff-try-send!
      (chan-close! (%diff-capture-done run))
    ) ;define
    (define (%pi-with-turn-diff run cfg emit execute)
      (if run
        (let ((observed-emit (%pi-diff-start run emit)))
          (dynamic-wind (lambda () #t)
            (lambda () (execute (%pi-diff-config run cfg) observed-emit))
            (lambda () (%pi-diff-finish! run))
          ) ;dynamic-wind
        ) ;let
        (execute cfg emit)
      ) ;if
    ) ;define
  ) ;begin
) ;define-library
