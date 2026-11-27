;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 会话结束后的响应处理：将 Agent 最终消息归一化并转换为统一的
;; 审查成功报告或可读错误。从 modes.scm 拆出，原 (gfcode code-review modes)
;; 入口仍重新导出 pi-code-review-response 以保持兼容。

(define-library (gfcode code-review response)
  (import (scheme base)
    (liii string)
    (liii list)
    (liii pi agent tools)
    (liii pi ai message)
    (gfcode code-review parse)
    (gfcode code-review format)
    (gfcode code-review result)
  ) ;import
  (export pi-code-review-response)
  (begin

    (define (%field alist key)
      (let ((pair (assoc key alist)))
        (if pair (cdr pair) '())
      ) ;let
    ) ;define

    (define (%normalize-blocks content)
      (let ((items (cond ((vector? content) (vector->list content))
                         ((list? content) content)
                         (else '())
                   ) ;cond
            ) ;items
           ) ;
        (map (lambda (blk) (if (pi-block? blk) (pi-block->json blk) blk)) items)
      ) ;let
    ) ;define

    (define (%message-alist msg)
      (cond ((pi-message? msg) (pi-message->json msg))
            ((pair? msg) msg)
            (else #f)
      ) ;cond
    ) ;define

    (define (%message-field key alt-key msg default)
      (let ((alist (%message-alist msg)))
        (if alist
          (let ((pair (or (assoc key alist) (assoc alt-key alist))))
            (if pair (cdr pair) default)
          ) ;let
          default
        ) ;if
      ) ;let
    ) ;define

    (define (%message-text msg)
      (let ((alist (%message-alist msg)))
        (if (not alist)
          ""
          (let* ((content (%field alist "content"))
                 (normalized (cons (cons "content" (%normalize-blocks content)) alist))
                ) ;
            (extract-assistant-text normalized)
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (%last-assistant-text msgs)
      (let loop
        ((rest (reverse msgs)))
        (cond ((null? rest) "")
              (else
                (let ((text (%message-text (car rest))))
                  (if (string-null? (string-trim-both text)) (loop (cdr rest)) text)
                ) ;let
              ) ;else
        ) ;cond
      ) ;let
    ) ;define

    (define (pi-code-review-response res-msgs)
      (let* ((last-msg (and (pair? res-msgs) (car (reverse res-msgs))))
             (stop-reason (%message-field "stopReason" 'stopReason last-msg #f))
             (err-msg (%message-field "errorMessage" 'errorMessage last-msg #f))
            ) ;
        (cond
         ((or (equal? stop-reason "error") (equal? stop-reason "aborted"))
          (make-review-error (or err-msg (string-append "Request " stop-reason)))
         ) ;
         ((equal? stop-reason "length")
          (make-review-error "Response was truncated: the model reached its output token limit."
          ) ;make-review-error
         ) ;
         (else
           (let ((findings (pi-parse-review-findings (%last-assistant-text res-msgs))))
             (make-review-ok (pi-format-review-findings findings))
           ) ;let
         ) ;else
        ) ;cond
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
