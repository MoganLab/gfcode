;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 助手纯文本回复卡片组件 (make-assistant-card text)
(define-library (liii pi app interactive views assistant)
  (export make-assistant-card assistant-card-append-text! assistant-card-text
    %assistant-id %assistant-revision %assistant-ready? %assistant-finish!
    %assistant-prefix! %assistant-finalize! assistant-card?
    assistant-card-component?
  ) ;export
  (import (scheme base)
    (only (liii list) take)
    (liii string)
    (liii pi code utils shell)
    (liii tui component)
    (liii pi app interactive views ansi-lines)
    (liii pi app interactive views cache)
    (liii pi app interactive views wrap)
  ) ;import
  (begin

    (define-record-type <assistant-card>
      (%make-assistant-card text id revision ready? rows source blocks? render-cache)
      assistant-card?
      (text %assistant-card-text %assistant-card-text-set!)
      (id %assistant-id)
      (revision %assistant-revision %assistant-revision-set!)
      (ready? %assistant-ready? %assistant-ready-set!)
      (rows %assistant-rows %assistant-rows-set!)
      (source %assistant-source %assistant-source-set!)
      (blocks? blocks? set-blocks!)
      (render-cache %assistant-card-render-cache)
    ) ;define-record-type

    ;; 助手正文透明无背景、无前缀符号；
    ;; 超宽行按内容宽度折行（右侧留 1 列边界），避免 alt-screen 截断吞掉内容；
    ;; 末尾保留一行空行作为卡片间隔
    (define (%render-assistant-card st width)
      (%cached-render (%assistant-card-render-cache st)
        (list (%assistant-revision st)
          (%assistant-ready? st)
          (%assistant-source st)
          width
          %diff-theme-revision
        ) ;list
        (lambda ()
          (if (<= width 0)
            '()
            (append
              (let ((rows (if (blocks? st) (or (%assistant-rows st) '()) (display-rows st))))
                (if rows
                  (%markdown-visual-lines rows (max 1 (- width 1)))
                  (%card-body-lines (%assistant-card-text st) width 0 1 list)
                ) ;if
              ) ;let
              (list "")
            ) ;append
          ) ;if
        ) ;lambda
      ) ;%cached-render
    ) ;define

    (define next-id 0)
    (define (%assistant-finish! st rev rows)
      (and (= rev (%assistant-revision st))
        (begin
          (%assistant-ready-set! st #t)
          (unless rows
            (set-blocks! st #f)
          ) ;unless
          (when (and rows (%markdown-rows? rows))
            (%assistant-source-set! st (sanitize-display-text (%assistant-card-text st)))
            (%assistant-rows-set! st rows)
          ) ;when
          #t
        ) ;begin
      ) ;and
    ) ;define
    (define (%assistant-finalize! st)
      (%assistant-revision-set! st (+ 1 (%assistant-revision st)))
      (%assistant-ready-set! st #f)
    ) ;define

    (define (%assistant-prefix! st rev source size rows keep)
      (and (exact-integer? size)
        (exact-integer? keep)
        (<= 0 keep (length (or (%assistant-rows st) '())))
        (<= 0 size (string-length source))
        (<= rev (%assistant-revision st))
        (%markdown-rows? rows)
        (begin
          (%assistant-ready-set! st (= rev (%assistant-revision st)))
          (%assistant-source-set! st (substring source 0 size))
          (%assistant-rows-set! st
            (append (take (or (%assistant-rows st) '()) keep) rows)
          ) ;%assistant-rows-set!
          #t
        ) ;begin
      ) ;and
    ) ;define

    (define (make-assistant-card text . block-mode)
      (set! next-id (+ next-id 1))
      (let* ((st (%make-assistant-card text
                   next-id
                   0
                   #f
                   #f
                   ""
                   (and (pair? block-mode) (car block-mode))
                   (%make-render-cache #f '())
                 ) ;%make-assistant-card
             ) ;st
             (card (make-component :render (lambda (self width) (%render-assistant-card st width)))
             ) ;card
            ) ;
        (component-data-set! card st)
        card
      ) ;let*
    ) ;define

    (define (assistant-card-text card)
      (%assistant-card-text (component-data card))
    ) ;define

    ;; Preserve the worker's styled prefix until the replacement arrives. Only
    ;; the last logical row can join the delta; wrap the joined row once.
    (define (display-rows st)
      (and (%assistant-rows st)
        (let ((text (sanitize-display-text (%assistant-card-text st)))
              (prefix (%assistant-source st))
             ) ;
          (cond ((string=? prefix text) (%assistant-rows st))
                ((string-starts? text prefix)
                 (extend-rows (%assistant-rows st)
                   (substring text (string-length prefix) (string-length text))
                 ) ;extend-rows
                ) ;
                (else #f)
          ) ;cond
        ) ;let
      ) ;and
    ) ;define

    (define (extend-rows rows delta)
      (let* ((back (reverse rows))
             (last (car back))
             (parts (string-split delta "\n"))
             (tail (car parts))
             (n (string-length tail))
            ) ;
        (append (reverse (cdr back))
          (list
            (cons (string-append (car last) tail)
              (append (cdr last)
                (if (zero? n) '() (list (list (string-length (car last)) n "Plain")))
              ) ;append
            ) ;cons
          ) ;list
          (map
            (lambda (s)
              (if (string=? s "") (list s) (list s (list 0 (string-length s) "Plain")))
            ) ;lambda
            (cdr parts)
          ) ;map
        ) ;append
      ) ;let*
    ) ;define

    (define (assistant-card-append-text! card delta)
      (when (and (string? delta) (not (string-null? delta)))
        (let ((st (component-data card)))
          (%assistant-revision-set! st (+ 1 (%assistant-revision st)))
          (%assistant-ready-set! st #f)
          (%assistant-card-text-set! st (string-append (%assistant-card-text st) delta))
        ) ;let
      ) ;when
    ) ;define

    (define (assistant-card-component? obj)
      (and (component? obj) (assistant-card? (component-data obj)))
    ) ;define

  ) ;begin
) ;define-library
