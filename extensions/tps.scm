;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License.
;;
;;
;; TPS 扩展：每次 agent 运行结束时输出一行 token 吞吐量统计。
;;
;; 输出形如：
;;   TPS 38.5 tok/s. out 414, in 848, cache r/w 15.8K/0, total 17.1K, 10.8s
;;
;; token 计数采用 human readable 紧凑记法（K=10^3, M=10^6）：
;;   - < 1000          token 计数输出整数（如 414、848）；
;;   - >= 1000         用 K/M 后缀，保留 1 位小数（如 15808 -> 15.8K，2531749 -> 2.5M）。
;; TPS 保留 1 位小数；耗时（秒）采用时长记法：29.4s / 1m30s / 1h5m。
;;
;; 移植自 pi 项目的 .pi/extensions/tps.ts（Mario Zechner）：
;;   - 记 agent_start 时间戳，agent_end 时计算墙钟耗时；
;;   - 累加所有 assistant 消息的 usage（input/output/cacheRead/cacheWrite/totalTokens）；
;;   - 输出优先走 ctx.ui.notify（TUI 下渲染为聊天区状态行，不进输入区），
;;     未 arm notify 时回退 stderr（verbose / 一次性运行场景）。

(import (scheme base)
  (liii list)
  (liii date-time)
  (liii pi ai time)
  (liii pi ai message)
  (liii pi code core extensions)
  (liii pi code core extension-notify)
  (liii pi code modes output)
) ;import

;; 盒子记录本轮 agent_start 的单调毫秒时间戳；多 run 串扰由 run 入口重置兜底。

(define %start-ms-box (cons #f #f))

(define (%start-ms-set! v)
  (set-car! %start-ms-box v)
) ;define

(define (%start-ms)
  (car %start-ms-box)
) ;define

;; 健壮取数：usage 中的值可能是数字或字符串（持久化后），统一转 inexact。

(define (%->num v)
  (cond ((number? v) (if (exact? v) (exact->inexact v) v))
        ((string? v)
         (let ((n (string->number v)))
           (if (number? n) (if (exact? n) (exact->inexact n) n) 0.0)
         ) ;let
        ) ;
        (else 0.0)
  ) ;cond
) ;define

;; 在 usage alist 中按符号/字符串两种键查找并取数。

(define (%usage-num usage key)
  (if (not (pair? usage))
    0.0
    (let ((p
            (or (assq key usage)
              (assoc (symbol->string key) usage)
              (assoc (string->symbol (symbol->string key)) usage)
            ) ;or
          ) ;p
         ) ;
      (if (pair? p) (%->num (cdr p)) 0.0)
    ) ;let
  ) ;if
) ;define

;; 判定是否 assistant 消息：兼容 record 与 dict（pair）形态。

(define (%assistant? m)
  (cond ((pi-assistant-message? m) #t)
        ((pair? m)
         (let ((role (pi-message-field m 'role #f)))
           (and (string? role) (string=? role "assistant"))
         ) ;let
        ) ;
        (else #f)
  ) ;cond
) ;define

;; 取 assistant 消息的 usage alist。

(define (%assistant-usage m)
  (if (pi-assistant-message? m)
    (or (pi-assistant-message-usage m) '())
    (or (pi-message-field m 'usage '()) '())
  ) ;if
) ;define

;; 对列表中的所有 usage 按 key 求和。

(define (%sum-usage-key usages key)
  (let loop
    ((lst usages) (acc 0.0))
    (if (null? lst) acc (loop (cdr lst) (+ acc (%usage-num (car lst) key))))
  ) ;let
) ;define

;; 把非负实数格式化为指定位数的小数字符串（不分组，不后缀）。
;; digits=0 时输出整数；digits>0 时按 digits 位小数输出并补零。

(define (%fixed-decimals x digits)
  (let* ((scale (expt 10 digits))
         (rounded (/ (round (* x scale)) scale))
         (int-part (inexact->exact (truncate rounded)))
         (int-str (number->string int-part))
        ) ;
    (if (= digits 0)
      int-str
      (let* ((frac-part
               (inexact->exact (round (* (- rounded int-part) scale)))
             ) ;frac-part
             (frac-str (number->string frac-part))
             (pad (- digits (string-length frac-str)))
            ) ;
        (string-append int-str
          "."
          (if (> pad 0) (string-append (make-string pad #\0) frac-str) frac-str)
        ) ;string-append
      ) ;let*
    ) ;if
  ) ;let*
) ;define

;; human readable 紧凑记法：把非负实数格式化为带 K/M 后缀的字符串。
;; raw-digits 控制原值档位（<1000）的小数位；km-digits 控制 K/M 档位的小数位。

(define (%human-readable x raw-digits km-digits)
  (cond ((not (number? x)) "0")
        ((< x 1000) (%fixed-decimals x raw-digits))
        ((< x 1000000) (string-append (%fixed-decimals (/ x 1000.0) km-digits) "K"))
        (else (string-append (%fixed-decimals (/ x 1000000.0) km-digits) "M"))
  ) ;cond
) ;define

;; 把 time-delta 格式化为 human readable 时长（从分量读回）：
;;   无 h 无 m      "29.4s"（秒保留 1 位小数）
;;   有 m 无 h      "1m30s"（余秒非零）或 "12m"（整分）
;;   有 h           "1h5m"（分取整数）。

(define (%format-duration dt)
  (let ((minutes (time-delta-minutes dt)) (hours (time-delta-hours dt)))
    (cond ((and (zero? minutes) (zero? hours))
           (string-append (%fixed-decimals (exact->inexact (time-delta-seconds dt)) 1) "s"))
          ((zero? hours)
           (let ((rest (time-delta-seconds dt)))
             (if (zero? rest)
               (string-append (number->string minutes) "m")
               (string-append (number->string minutes)
                 "m"
                 (%fixed-decimals (exact->inexact rest) 0)
                 "s"
               ) ;string-append
             ) ;if
           ) ;let
          ) ;
          (else (string-append (number->string hours) "h" (number->string minutes) "m"))
    ) ;cond
  ) ;let
) ;define

;; 组装最终的 TPS 行。

(define (%tps-line tps out in cr cw total elapsed-dt)
  (string-append "TPS "
    (%human-readable tps 1 1)
    " tok/s. "
    "out "
    (%human-readable out 0 1)
    ", "
    "in "
    (%human-readable in 0 1)
    ", "
    "cache r/w "
    (%human-readable cr 0 1)
    "/"
    (%human-readable cw 0 1)
    ", "
    "total "
    (%human-readable total 0 1)
    ", "
    (%format-duration elapsed-dt)
  ) ;string-append
) ;define

;; 取 stderr 端口：优先 *stderr*，否则 current-error-port。

(define (%stderr-port)
  (if (defined? '*stderr*) *stderr* (current-error-port))
) ;define

(define (tps-extension api . opt-context)
  (pi-on! api
    'agent_start
    (lambda (payload ctx) (%start-ms-set! (pi-current-monotonic-millis)))
  ) ;pi-on!

  (pi-on! api
    'agent_end
    (lambda (payload ctx)
      (let ((start-ms (%start-ms)))
        ;; 无配对的 start 时戳则跳过（避免误触发）
        (when start-ms
          (%start-ms-set! #f)
          (let* ((messages
                   (let ((p (and (pair? payload) (assq 'messages payload))))
                     (if (pair? p) (cdr p) '())
                   ) ;let
                 ) ;messages
                 (assistant-usages (map %assistant-usage (filter %assistant? messages)))
                 (out (%sum-usage-key assistant-usages 'output))
                 (in (%sum-usage-key assistant-usages 'input))
                 (cr (%sum-usage-key assistant-usages 'cacheRead))
                 (cw (%sum-usage-key assistant-usages 'cacheWrite))
                 (total (%sum-usage-key assistant-usages 'totalTokens))
                 (elapsed-ms (- (pi-current-monotonic-millis) start-ms))
                 (elapsed-dt (milliseconds-delta elapsed-ms))
                 (elapsed-s (if (number? elapsed-ms) (/ elapsed-ms 1000.0) 0.0))
                 (tps (if (> elapsed-s 0) (/ out elapsed-s) 0.0))
                ) ;
            ;; 仅在确实有输出 token 时输出。对齐上游 ctx.ui.notify / ctx.hasUI：
            ;; 优先用 ctx 携带的 notify（TUI 已 arm），其次全局注入点，最后回退 stderr。
            (when (> out 0)
              (let ((line (%tps-line tps out in cr cw total elapsed-dt))
                    (ctx-notify (and ctx (extension-context-notify ctx)))
                   ) ;
                (unless (and (procedure? ctx-notify) (ctx-notify line))
                  (unless (pi-extension-notify line)
                    (let ((port (%stderr-port)))
                      (display line port)
                      (newline port)
                    ) ;let
                  ) ;unless
                ) ;unless
              ) ;let
            ) ;when
          ) ;let*
        ) ;when
      ) ;let
    ) ;lambda
  ) ;pi-on!

  "tps-loaded"
) ;define

tps-extension
