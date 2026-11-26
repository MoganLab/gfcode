;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code modes verbose message)
  (import (scheme base)
    (scheme write)
    (liii string)
    (liii pi ai message)
    (liii pi code modes output)
    (liii pi code modes verbose common)
    (liii pi code modes verbose state)
    (liii pi code modes verbose thinking)
  ) ;import
  (export display-message-line flush-message-lines flush-message-tail
    %handle-message-start! %handle-message-update! %handle-message-end!
  ) ;export
  (begin

    (define (display-message-line turn-box line port)
      ;; 本条消息的第一行带 💬 前缀，续行直接输出
      (display (if (caddr turn-box)
                 (string-append line "\n")
                 (string-append "💬 " line "\n")
               ) ;if
        port
      ) ;display
    ) ;define

    (define (flush-message-lines turn-box port)
      ;; 合并增量后，遇到 \n 就立即打印完整行
      (let loop
        ()
        (let* ((buf (cadr turn-box)) (idx (%substring-index "\n" buf)))
          (when idx
            (let ((line (substring buf 0 idx))
                  (rest (substring buf (+ idx 1) (string-length buf)))
                 ) ;
              (display-message-line turn-box line port)
              (set-car! (cddr turn-box) #t)
              (set-car! (cdr turn-box) rest)
              (loop)
            ) ;let
          ) ;when
        ) ;let*
      ) ;let
    ) ;define

    (define (flush-message-tail turn-box port)
      ;; message 结束时打印剩余未换行的尾部，并复位缓冲
      (let ((message (string-trim-both (cadr turn-box))))
        (when (> (string-length message) 0)
          (display-message-line turn-box message port)
        ) ;when
        (set-car! (cdr turn-box) "")
        (set-car! (cddr turn-box) #f)
      ) ;let
    ) ;define

    (define (%handle-message-start! ev turn-box)
      ;; 实测 pi (JSON mode) 的 wire 顺序：assistant 的 message_update
      ;; 增量先于 message_start(assistant) 到达，因此仅对 user 角色
      ;; 重置缓冲，避免清空尚未 flush 的助手文本（toolResult 同理）。
      (let* ((msg (%normalize-message (%prop-ref ev 'message "message" '())))
             (role (%prop-string msg 'role "role" ""))
            ) ;
        (when (string=? role "user")
          (set-car! (cdr turn-box) "")
          (set-car! (cddr turn-box) #f)
        ) ;when
      ) ;let*
    ) ;define

    (define (%handle-message-update! ev turn-box port)
      (let* ((msg-ev (%prop-ref ev 'assistantMessageEvent "assistantMessageEvent" '()))
             (ev-type (%prop-string msg-ev 'type "type" ""))
            ) ;
        (cond ((string=? ev-type "thinking_start") (%handle-thinking-start! turn-box port))
              ((string=? ev-type "thinking_delta") (%handle-thinking-delta! turn-box port))
              ((string=? ev-type "thinking_end") (%handle-thinking-end! turn-box port))
              ((string=? ev-type "text_delta")
               (let ((delta (%prop-string msg-ev 'delta "delta" "")))
                 (set-car! (cdr turn-box) (string-append (cadr turn-box) delta))
                 (flush-message-lines turn-box port)
               ) ;let
              ) ;
              (else #f)
        ) ;cond
      ) ;let*
    ) ;define

    (define (%handle-message-end! ev turn-box port)
      (let* ((msg (%normalize-message (%prop-ref ev 'message "message" '())))
             (role (%prop-string msg 'role "role" ""))
             (stop-reason (%prop-string msg 'stopReason "stopReason" ""))
             (err-msg (%prop-string msg 'errorMessage "errorMessage" ""))
            ) ;
        ;; 流式思考未正常结束（如请求被截断/中断）时兜底收尾，
        ;; 避免思考状态悬挂到下一轮
        (let ((tb (%thinking-box turn-box)))
          (when (and (vector? tb) (vector-ref tb 0))
            (%handle-thinking-end! turn-box port)
          ) ;when
        ) ;let
        (when (and (string=? role "assistant")
                (or (string=? stop-reason "error") (string=? stop-reason "aborted"))
              ) ;and
          (display (format #f
                     "❌ [error] ~a\n"
                     (if (string-null? err-msg) (string-append "Request " stop-reason) err-msg)
                   ) ;format
            port
          ) ;display
        ) ;when
        (when (string=? role "assistant")
          (when (and (not (caddr turn-box)) (string-null? (cadr turn-box)))
            (let* ((content (%prop-ref msg 'content "content" '()))
                   (txt (pi-content-text content))
                  ) ;
              (when (and (string? txt) (not (string-null? txt)))
                (set-car! (cdr turn-box) txt)
                (flush-message-lines turn-box port)
              ) ;when
            ) ;let*
          ) ;when
        ) ;when
      ) ;let*
      (flush-message-tail turn-box port)
    ) ;define

  ) ;begin
) ;define-library
