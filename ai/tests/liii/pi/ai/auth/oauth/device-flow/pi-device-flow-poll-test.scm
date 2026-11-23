;; pi-device-flow-poll
;; RFC 8628 设备码通用轮询循环：pending/slow_down/failed/complete 四态。
;;
;; 语法
;; ----
;; (pi-device-flow-poll poll)
;; (pi-device-flow-poll poll interval-seconds expires-in-seconds wait-before-first-poll? cancelled?)
;;
;; 参数
;; ----
;; poll : procedure?
;; 零参过程，返回 (pending) / (slow_down [interval]) / (failed msg) / (complete value)。
;;
;; interval-seconds : number?
;; 轮询间隔秒数（最小 1s，默认 5s）。
;;
;; expires-in-seconds : number? 或 #f
;; 总超时秒数；#f 表示不限时。
;;
;; wait-before-first-poll? : boolean?
;; #t 时首轮先等一个 interval（Kimi 流程语义）。
;;
;; cancelled? : procedure? 或 #f
;; 取消谓词；置位时抛 kimi-oauth-cancelled。
;;
;; 返回值
;; ----
;; any
;; complete 的 value；failed/取消/超时抛 kimi-oauth-error / kimi-oauth-cancelled。

(import (scheme base)
  (liii check)
  (liii string)
  (liii pi ai auth oauth device-flow)
) ;import

(check-set-mode! 'report-failed)

(check-catch 'type-error (pi-device-flow-poll "not-a-proc"))

;; 1. 立即 complete
(check (pi-device-flow-poll (lambda () '(complete ok)) 0.01 10 #f #f) => 'ok)

;; 2. pending 两次后 complete
(let ((n 0))
  (check
    (pi-device-flow-poll (lambda () (set! n (+ n 1)) (if (< n 3) '(pending) '(complete done)))
      0.01
      10
      #f
      #f
    ) ;pi-device-flow-poll
    =>
    'done
  ) ;check
  (check n => 3)
) ;let

;; 3. failed 抛 kimi-oauth-error 且携带消息
(check-catch 'kimi-oauth-error
  (pi-device-flow-poll (lambda () '(failed "denied by user")) 0.01 10 #f #f)
) ;check-catch
(let ((msg
        (catch 'kimi-oauth-error
          (lambda ()
            (pi-device-flow-poll (lambda () '(failed "denied by user")) 0.01 10 #f #f)
          ) ;lambda
          (lambda (tag . info) (caar info))
        ) ;catch
      ) ;msg
     ) ;
  (check msg => "denied by user")
) ;let

;; 4. 超时（expires 已过）抛超时错误
(check-catch 'kimi-oauth-error
  (pi-device-flow-poll (lambda () '(pending)) 1 0 #f #f)
) ;check-catch

;; 5. slow_down 后超时：错误消息提示时钟漂移
(let ((msg
        (catch 'kimi-oauth-error
          (lambda () (pi-device-flow-poll (lambda () '(slow_down)) 1 0.001 #f #f))
          (lambda (tag . info) (caar info))
        ) ;catch
      ) ;msg
     ) ;
  (check-true (string-contains? msg "slow_down"))
) ;let

;; 6. slow_down 携带服务端新 interval，随后 complete
(let ((n 0))
  (check
    (pi-device-flow-poll
      (lambda ()
        (set! n (+ n 1))
        (case n
         ((1) '(slow_down 0.01))
         ((2) '(pending))
         (else '(complete late))
        ) ;case
      ) ;lambda
      0.01
      30
      #f
      #f
    ) ;pi-device-flow-poll
    =>
    'late
  ) ;check
) ;let

;; 7. 取消谓词置位：抛 kimi-oauth-cancelled
(check-catch 'kimi-oauth-cancelled
  (pi-device-flow-poll (lambda () '(pending)) 0.01 10 #f (lambda () #t))
) ;check-catch

;; 8. wait-before-first-poll? 首轮先等待（用取消谓词在等待中生效验证）
(let ((cancelled #f))
  (check-catch 'kimi-oauth-cancelled
    (pi-device-flow-poll (lambda () (set! cancelled #t) '(pending))
      3
      30
      #t
      (lambda () cancelled)
    ) ;pi-device-flow-poll
  ) ;check-catch
) ;let

(check-report)
