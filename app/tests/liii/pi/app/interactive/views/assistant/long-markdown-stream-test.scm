;; %worker-markdown-parser
;; 对比 cat block 回调与实时卡片的每一次可见更新。
;; 语法
;; ----
;; (worker raw card-id final?)
;; 参数
;; ----
;; raw 为累积原文；final? 仅在 EOF 为真。
;; 返回值
;; ----
;; 每个已完成块对应一个展示补丁；未完成时为空列表。
(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii highlight stream-ansi)
  (liii highlight theme)
  (liii highlight definition)
  (liii tui component)
  (liii tui text-width)
  (liii pi app interactive views assistant)
  (liii pi app interactive views markdown)
) ;import
(check-set-mode! 'report-failed)

(define doc
  "# 标题\n\nparagraph\ncontinued\n\n- one\n- two\n\n```scheme\n(a)\n(b)\n```\n\n## 尾部"
) ;define

(define (cat-blocks raw)
  (let ((pieces '()) (in (open-input-string raw)) (out (open-output-string)))
    (dynamic-wind (lambda () #f)
      (lambda ()
        (highlight-port-to-ansi-mode in
          out
          (load-syntax-definition "markdown")
          (default-breeze-dark-theme)
          'block
          (lambda (s) (set! pieces (cons (strip-ansi s) pieces)))
          1
        ) ;highlight-port-to-ansi-mode
      ) ;lambda
      (lambda () (close-input-port in) (close-output-port out))
    ) ;dynamic-wind
    (reverse pieces)
  ) ;let
) ;define

(define (replay step)
  (let ((work (%worker-markdown-parser))
        (at 0)
        (pieces '())
        (shown "")
        (card (make-assistant-card "" #t))
       ) ;
    (let loop
      ((start 0))
      (let* ((end (min (string-length doc) (+ start step)))
             (raw (substring doc 0 end))
             (delta (substring doc start end))
            ) ;
        (assistant-card-append-text! card delta)
        (check (map strip-ansi (component-render card 300))
          =>
          (if (null? pieces) '("") (append (string-split shown "\n") '("")))
        ) ;check
        (for-each
          (lambda (p)
            (let* ((leaf (list-ref expected (length pieces))) (stop (car p)))
              (check (substring raw (- stop (string-length leaf)) stop) => leaf)
              (set! pieces (cons leaf pieces))
              (set! shown (string-append shown leaf))
            ) ;let*
            (set! at (car p))
            (apply %assistant-prefix!
              (component-data card)
              (%assistant-revision (component-data card))
              raw
              p
            ) ;apply
            (check (map strip-ansi (component-render card 300))
              =>
              (append (string-split shown "\n") '(""))
            ) ;check
          ) ;lambda
          (work raw 1 (= end (string-length doc)))
        ) ;for-each
        (when (< end (string-length doc))
          (loop end)
        ) ;when
      ) ;let*
    ) ;let
    (check (assistant-card-text card) => doc)
    (reverse pieces)
  ) ;let
) ;define

(define expected (cat-blocks doc))
(check (replay 1) => expected)
(check (replay 19) => expected)
(check (replay 8192) => expected)

(define work (%worker-markdown-parser))

(define intro
  (apply string-append
    (make-list 150 (string-append "## H " (make-string 110 #\a) "\n"))
  ) ;apply
) ;define
(check (work intro 2 #f) => '())
(check (work "|a|b|\n|-|-|\n" 3 #f) => '())

(define end (string-append intro (make-string 2100 #\a) "\n## 3.7"))

(define p (car (work end 2 #t)))
(check (car p) => (string-length end))
(check (car (reverse (cadr p))) => '("## 3.7" (0 6 "Heading")))

(define t (car (work "|a|b|\n|---|---|\n" 3 #t)))
(check (caddr (cadar (cadr t))) => "TableBorder")

(check-report)
