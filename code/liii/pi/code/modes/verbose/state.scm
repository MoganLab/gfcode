;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code modes verbose state)
  (import (scheme base))
  (export ensure-message-slots %thinking-box)
  (begin

    ;; turn-box 结构: (轮次 消息缓冲 是否已打印过本条消息的行 思考状态盒)
    ;; 思考状态盒为 vector #(active? start-ms last-ping-ms)，由 ensure 惰性补齐
    (define (ensure-message-slots turn-box)
      ;; 每个槽位单独补齐：每条 when 只追加一个元素，
      ;; 避免在 turn-box 元素不足时把思考状态盒误置为 #f。
      (when (null? (cdr turn-box))
        (set-cdr! turn-box (list ""))
      ) ;when
      (when (null? (cddr turn-box))
        (set-cdr! (cdr turn-box) (list #f))
      ) ;when
      (when (null? (cdddr turn-box))
        (set-cdr! (cddr turn-box) (list (vector #f 0 0)))
      ) ;when
    ) ;define

    (define (%thinking-box turn-box)
      ;; 先确保思考状态槽补齐再访问 cadddr，避免 turn-box 元素不足时抛错；
      ;; turn-box 非 pair 时返回 #f（调用方均已用 (vector? tb) 守卫）
      (if (pair? turn-box)
        (begin
          (ensure-message-slots turn-box)
          (cadddr turn-box)
        ) ;begin
        #f
      ) ;if
    ) ;define

  ) ;begin
) ;define-library
