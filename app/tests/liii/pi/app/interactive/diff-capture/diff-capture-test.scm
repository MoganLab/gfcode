;; %pi-diff-executor
;; 包装原工具执行器，并按同一轮的工具事件捕获有界快照。
;;
;; 语法
;; ----
;; (%pi-diff-executor run execute)
;;
;; 参数
;; ----
;; run : 本轮快照状态，由 %pi-make-diff-capture 构造。
;; execute : 原工具执行过程，接收工具名、参数和可选项。
;;
;; 返回值
;; ----
;; procedure?。原样返回工具结果并传播原工具异常；快照不可用时跳过 diff。
(import (scheme base)
  (scheme file)
  (liii check)
  (liii go)
  (liii path)
  (liii tempfile)
  (liii pi ai tools result)
  (liii pi code core tools)
  (liii pi code core tools read)
  (liii pi app interactive diff-capture)
) ;import

(check-set-mode! 'report-failed)

(define tmp (make-temp-dir "gf-pi-diff-capture-"))

(define target (path->string (path-join tmp "sample.txt")))

(define jobs (make-chan 2))

(define run (%pi-make-diff-capture 1 jobs #f))

(define calls 0)

(define original #f)

(define emit (%pi-diff-emit run (lambda args args)))

(define exec
  (%pi-diff-executor run
    (lambda args
      (set! calls (+ calls 1))
      (set! original (apply execute-tool-call args))
      original
    ) ;lambda
  ) ;%pi-diff-executor
) ;define

(define (write-args body)
  (list (cons "path" "sample.txt") (cons "content" body))
) ;define

(define (run-tool id name args)
  (check (emit 'tool_execution_start id name args)
    =>
    (list 'tool_execution_start id name args)
  ) ;check
  (let ((result (exec name args :cwd tmp)))
    (check (eq? result original) => #t)
    (emit 'tool_execution_end id name result (pi-tool-result-is-error result))
    result
  ) ;let
) ;define

(dynamic-wind (lambda () #t)
  (lambda ()
    (check-false (pi-tool-result-is-error (run-tool "write" "write" (write-args "one\n")))
    ) ;check-false
    (check-false
      (pi-tool-result-is-error (run-tool "edit"
                                 "edit"
                                 '(("path" . "./sample.txt")
                                   ("edits"
                                    . #((("oldText" . "one")
                                         ("newText" . "two"))
                                      ) ;#
                                   ))
                               ) ;run-tool
      ) ;pi-tool-result-is-error
    ) ;check-false
    (check-true
      (pi-tool-result-is-error (run-tool "bad" "write" '(("path" . #f)
                                                         ("content" . "no")))
      ) ;pi-tool-result-is-error
    ) ;check-true
    (let ((write-job (chan-try-recv! jobs #f)) (edit-job (chan-try-recv! jobs #f)))
      (check (list-tail write-job 3)
        =>
        (list "sample.txt"
          (pi-resolve-path target tmp)
          ""
          "one\n"
          (%diff-capture-done run)
        ) ;list
      ) ;check
      (check (list-tail edit-job 3)
        =>
        (list "./sample.txt"
          (pi-resolve-path target tmp)
          "one\n"
          "two\n"
          (%diff-capture-done run)
        ) ;list
      ) ;check
      (check (chan-try-recv! jobs #f) => #f)
      (check (path-read-text target) => "two\n")
    ) ;let
    ;; Goldfish can report success from write on a directory; no stats should
    ;; be fabricated in that case, regardless of the original result's status.
    (let ((directory-write
            (run-tool "directory" "write" `(("path" . ,tmp) ("content" . "bad")))
          ) ;directory-write
         ) ;
      (unless (pi-tool-result-is-error directory-write)
        (check (list-tail (chan-try-recv! jobs #f) 5)
          =>
          (list #f #f (%diff-capture-done run))
        ) ;check
      ) ;unless
    ) ;let
    (check (%diff-text-snapshot (string #\a #\nul #\b)) => #f)
    ;; A large snapshot does not change the original result.
    (check-false
      (pi-tool-result-is-error (run-tool "large" "write" (write-args (make-string 262145 #\z)))
      ) ;pi-tool-result-is-error
    ) ;check-false
    (check (list-tail (chan-try-recv! jobs #f) 5)
      =>
      (list #f #f (%diff-capture-done run))
    ) ;check
    (check-false (pi-tool-result-is-error (run-tool "overwrite" "write" (write-args "small\n")))
    ) ;check-false
    (check (list-tail (chan-try-recv! jobs #f) 5)
      =>
      (list #f #f (%diff-capture-done run))
    ) ;check
    ;; Saturate the job queue: no worker is consuming while the tool completes.
    (chan-try-send! jobs 'busy)
    (chan-try-send! jobs 'busy)
    (check-false (pi-tool-result-is-error (run-tool "full" "write" (write-args "full\n")))
    ) ;check-false
    (%pi-diff-finish! run)
    (check calls => 7)
    (check (path-read-text target) => "full\n")
  ) ;lambda
  (lambda ()
    (chan-close! jobs)
    (when (file-exists? target)
      (delete-file target)
    ) ;when
    (path-rmdir tmp)
  ) ;lambda
) ;dynamic-wind

(check-report)
