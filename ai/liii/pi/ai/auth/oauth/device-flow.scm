;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; RFC 8628 设备码通用轮询循环，翻译自上游 pi 仓库（本地 ~/git/pi）
;; packages/ai/src/auth/oauth/device-code.ts 的 pollOAuthDeviceCodeFlow。
;; gfcode 无 AbortSignal，取消靠 cancelled? 谓词（TUI 组件层置位）。
(define-library (liii pi ai auth oauth device-flow)
  (import (scheme base) (liii error) (liii time) (liii pi ai time))
  (export pi-device-flow-poll PI_DEVICE_FLOW_CANCEL_MESSAGE
    PI_DEVICE_FLOW_TIMEOUT_MESSAGE PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE
  ) ;export
  (begin

    (define PI_DEVICE_FLOW_CANCEL_MESSAGE "Login cancelled")
    (define PI_DEVICE_FLOW_TIMEOUT_MESSAGE "Device flow timed out")
    (define PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE
      (string-append "Device flow timed out after one or more slow_down responses. "
        "This is often caused by clock drift in WSL or VM environments. "
        "Please sync or restart the VM clock and try again."
      ) ;string-append
    ) ;define

    (define %minimum-interval-ms 1000)
    ;; RFC 8628 §3.2：服务端未给 interval 时客户端必须用 5 秒
    (define %default-poll-interval-seconds 5)
    ;; RFC 8628 §3.5：slow_down 时轮询间隔须增加 5 秒
    (define %slow-down-increment-ms 5000)
    ;; 分片睡眠粒度：每片醒来检查 cancelled?，取消响应 ≤ 0.1s
    (define %sleep-slice-seconds 0.1)

    ;; 可取消睡眠：分片 sleep，任一片间发现 cancelled? 即抛取消错误
    (define (%abortable-sleep seconds cancelled?)
      (let loop
        ((remaining seconds))
        (when (and cancelled? (cancelled?))
          (error 'kimi-oauth-cancelled PI_DEVICE_FLOW_CANCEL_MESSAGE)
        ) ;when
        (when (> remaining 0)
          (let ((slice (min %sleep-slice-seconds remaining)))
            (sleep slice)
            (loop (- remaining slice))
          ) ;let
        ) ;when
      ) ;let
    ) ;define

    ;; poll 结果协议（对应 pi 的 OAuthDeviceCodePollResult）：
    ;;   (pending) | (slow_down [interval-seconds]) | (failed message)
    ;;   | (complete value)
    ;; 返回 complete 的 value；failed/取消/超时抛错。
    ;; cancelled? 为 #f 或零参谓词；wait-before-first-poll? 对齐 pi 的
    ;; waitBeforeFirstPoll（Kimi 流程首轮先等一个 interval）。
    (define* (pi-device-flow-poll poll
               (interval-seconds %default-poll-interval-seconds)
               (expires-in-seconds #f)
               (wait-before-first-poll? #f)
               (cancelled? #f)
             ) ;pi-device-flow-poll
      (unless (procedure? poll)
        (type-error "pi-device-flow-poll: poll must be a procedure" poll)
      ) ;unless
      (let* ((start-ms (pi-current-monotonic-millis))
             (deadline-ms (and (number? expires-in-seconds) (+ start-ms (* expires-in-seconds 1000)))
             ) ;deadline-ms
             (interval-ms
               (max %minimum-interval-ms
                 (inexact->exact
                   (floor
                     (* (if (and (number? interval-seconds) (> interval-seconds 0))
                          interval-seconds
                          %default-poll-interval-seconds
                        ) ;if
                       1000
                     ) ;*
                   ) ;floor
                 ) ;inexact->exact
               ) ;max
             ) ;interval-ms
             (slow-down-count 0)
            ) ;
        (define (remaining-ms)
          (if deadline-ms (- deadline-ms (pi-current-monotonic-millis)) +inf.0)
        ) ;define
        (define (sleep-interval!)
          (let ((rem (remaining-ms)))
            (when (> rem 0)
              (%abortable-sleep (/ (min interval-ms rem) 1000) cancelled?)
            ) ;when
          ) ;let
        ) ;define
        (when (and wait-before-first-poll? (> (remaining-ms) 0))
          (sleep-interval!)
        ) ;when
        (let loop
          ()
          (when (and cancelled? (cancelled?))
            (error 'kimi-oauth-cancelled PI_DEVICE_FLOW_CANCEL_MESSAGE)
          ) ;when
          (if (<= (remaining-ms) 0)
            (error 'kimi-oauth-error
              (if (> slow-down-count 0)
                PI_DEVICE_FLOW_SLOW_DOWN_TIMEOUT_MESSAGE
                PI_DEVICE_FLOW_TIMEOUT_MESSAGE
              ) ;if
            ) ;error
            (let ((result (poll)))
              (case (and (pair? result) (car result))
                    ((complete) (cadr result))
                    ((failed)
                     (error 'kimi-oauth-error
                       (if (and (pair? (cdr result)) (string? (cadr result)))
                         (cadr result)
                         "Device flow failed"
                       ) ;if
                     ) ;error
                    ) ;
                    (else
                      (when (eq? (and (pair? result) (car result)) 'slow_down)
                        (set! slow-down-count (+ slow-down-count 1))
                        ;; 服务端给了新 interval 就采信（对齐 pi：WSL/VM 时钟漂移
                        ;; 下只靠客户端累加会永远提前轮询）；否则按 RFC 8628 +5s
                        (let ((server-interval (and (pair? (cdr result)) (cadr result))))
                          (set! interval-ms
                            (if (and (number? server-interval) (> server-interval 0))
                              (max %minimum-interval-ms (inexact->exact (floor (* server-interval 1000))))
                              (max %minimum-interval-ms (+ interval-ms %slow-down-increment-ms))
                            ) ;if
                          ) ;set!
                        ) ;let
                      ) ;when
                      (sleep-interval!)
                      (loop)
                    ) ;else
              ) ;case
            ) ;let
          ) ;if
        ) ;let
      ) ;let*
    ) ;define*

  ) ;begin
) ;define-library
