;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 助手纯文本回复卡片组件 (make-assistant-card text)
(define-library (liii pi app interactive views assistant)
  (export make-assistant-card assistant-card-append-text! assistant-card-text
    %assistant-id %assistant-revision %assistant-ready? %assistant-finish!
    assistant-card? assistant-card-component?
  ) ;export
  (import (scheme base)
    (liii string)
    (liii tui component)
    (liii pi app interactive views ansi-lines)
    (liii pi app interactive views cache)
    (liii pi app interactive views wrap)
  ) ;import
  (begin

    (define-record-type <assistant-card>
      (%make-assistant-card text id revision ready? rows render-cache)
      assistant-card?
      (text %assistant-card-text %assistant-card-text-set!)
      (id %assistant-id)
      (revision %assistant-revision %assistant-revision-set!)
      (ready? %assistant-ready? %assistant-ready-set!)
      (rows %assistant-rows %assistant-rows-set!)
      (render-cache %assistant-card-render-cache)
    ) ;define-record-type

    ;; 助手正文透明无背景、无前缀符号；
    ;; 超宽行按内容宽度折行（右侧留 1 列边界），避免 alt-screen 截断吞掉内容；
    ;; 末尾保留一行空行作为卡片间隔
    (define (%render-assistant-card st width)
      (%cached-render (%assistant-card-render-cache st)
        (list (%assistant-revision st)
          (%assistant-ready? st)
          width
          %diff-theme-revision
        ) ;list
        (lambda ()
          (if (<= width 0)
            '()
            (append
              (or
                (and (%assistant-rows st)
                  (catch #t
                    (lambda () (%markdown-visual-lines (%assistant-rows st) (max 1 (- width 1))))
                    (lambda args (%assistant-rows-set! st #f) #f)
                  ) ;catch
                ) ;and
                (%card-body-lines (%assistant-card-text st) width 0 1 list)
              ) ;or
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
          (%assistant-rows-set! st (and rows (%markdown-rows? rows) rows))
          #t
        ) ;begin
      ) ;and
    ) ;define
    (define (make-assistant-card text)
      (set! next-id (+ next-id 1))
      (let* ((st (%make-assistant-card text next-id 0 #f #f (%make-render-cache #f '())))
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

    (define (assistant-card-append-text! card delta)
      (when (and (string? delta) (not (string-null? delta)))
        (let ((st (component-data card)))
          (%assistant-revision-set! st (+ 1 (%assistant-revision st)))
          (%assistant-ready-set! st #f)
          (%assistant-rows-set! st #f)
          (%assistant-card-text-set! st (string-append (%assistant-card-text st) delta))
        ) ;let
      ) ;when
    ) ;define

    (define (assistant-card-component? obj)
      (and (component? obj) (assistant-card? (component-data obj)))
    ) ;define

  ) ;begin
) ;define-library
