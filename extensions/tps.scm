;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License.
;;
;;
;; TPS 扩展：每次 agent 运行结束时输出一行 token 吞吐量统计。
;;
;; 输出形如：
;;   TPS 38.5 tok/s. out 414, in 848, cache r/w 15,808/0, total 17,070, 10.8s
;;
;; 移植自 pi 项目的 .pi/extensions/tps.ts（Mario Zechner）：
;;   - 记 agent_start 时间戳，agent_end 时计算墙钟耗时；
;;   - 累加所有 assistant 消息的 usage（input/output/cacheRead/cacheWrite/totalTokens）；
;;   - 输出优先走 ctx.ui.notify（TUI 下渲染为聊天区状态行，不进输入区），
;;     未 arm notify 时回退 stderr（verbose / 一次性运行场景）。

(import (scheme base)
  (liii string)
  (liii list)
  (liii pi ai time)
  (liii pi ai message)
  (liii pi code core extensions)
  (liii pi code core extension-notify)
  (liii pi code modes output)
) ;import

;; 盒子记录本轮 agent_start 的单调毫秒时间戳；多 run 串扰由 run 入口重置兜底。
(define %start-ms-box (cons #f #f))
(define (%start-ms-set! v) (set-car! %start-ms-box v))
(define (%start-ms) (car %start-ms-box))

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
    (let ((p (or (assq key usage)
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
  (let loop ((lst usages) (acc 0.0))
    (if (null? lst)
      acc
      (loop (cdr lst) (+ acc (%usage-num (car lst) key)))
    ) ;if
  ) ;let
) ;define

;; 千分位格式化：整数部分按三位分组，例如 15808 -> "15,808"。
(define (%group-digits n-str)
  (let* ((len (string-length n-str))
         ;; 自右向左每 3 个字符切一组
         (groups
           (let loop ((i len) (acc '()))
             (if (<= i 0)
               acc
               (let ((start (max 0 (- i 3))))
                 (loop start (cons (substring n-str start i) acc))
               ) ;let
             ) ;if
           ) ;loop
          ) ;groups
        ) ;
    (string-join groups ",")
  ) ;let*
) ;define

;; 把非负实数格式化为带千分位的字符串（小数部分保留指定位，不加分隔）。
(define (%format-grouped x digits)
  (if (not (number? x))
    "0"
    (let* ((rounded (let ((scale (expt 10 digits)))
                      (/ (round (* x scale)) scale)
                    ) ;let
                  ) ;rounded
           (int-part (inexact->exact (truncate rounded)))
           (frac-part (inexact->exact (round (* (- rounded int-part) (expt 10 digits)))))
           (int-str (number->string int-part))
           (grouped (%group-digits int-str))
          ) ;
      (if (= digits 0)
        grouped
        (let* ((frac-str (number->string frac-part))
               (frac-padded
                 (let ((pad (- digits (string-length frac-str))))
                   (if (> pad 0)
                     (string-append (make-string pad #\0) frac-str)
                     frac-str
                   ) ;if
                 ) ;let
               ) ;frac-padded
              ) ;
          (string-append grouped "." frac-padded)
        ) ;let*
      ) ;if
    ) ;let
  ) ;if
) ;define

;; 组装最终的 TPS 行。
(define (%tps-line tps out in cr cw total elapsed-s)
  (string-append "TPS " (%format-grouped tps 1) " tok/s. "
    "out " (%format-grouped out 0) ", "
    "in " (%format-grouped in 0) ", "
    "cache r/w " (%format-grouped cr 0) "/" (%format-grouped cw 0) ", "
    "total " (%format-grouped total 0) ", "
    (%format-grouped elapsed-s 1) "s"
  ) ;string-append
) ;define

;; 取 stderr 端口：优先 *stderr*，否则 current-error-port。
(define (%stderr-port)
  (if (defined? '*stderr*) *stderr* (current-error-port))
) ;define

(define (tps-extension api . opt-context)
  (pi-on! api 'agent_start
    (lambda (payload ctx)
      (%start-ms-set! (pi-current-monotonic-millis))
    ) ;lambda
  ) ;pi-on!

  (pi-on! api 'agent_end
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
                 (assistant-usages
                   (map %assistant-usage (filter %assistant? messages))
                  ) ;assistant-usages
                 (out (%sum-usage-key assistant-usages 'output))
                 (in (%sum-usage-key assistant-usages 'input))
                 (cr (%sum-usage-key assistant-usages 'cacheRead))
                 (cw (%sum-usage-key assistant-usages 'cacheWrite))
                 (total (%sum-usage-key assistant-usages 'totalTokens))
                 (elapsed-ms (- (pi-current-monotonic-millis) start-ms))
                 (elapsed-s (if (number? elapsed-ms) (/ elapsed-ms 1000.0) 0.0))
                 (tps (if (> elapsed-s 0) (/ out elapsed-s) 0.0))
                ) ;
            ;; 仅在确实有输出 token 时输出。对齐上游 ctx.ui.notify / ctx.hasUI：
            ;; 优先用 ctx 携带的 notify（TUI 已 arm），其次全局注入点，最后回退 stderr。
            (when (> out 0)
              (let ((line (%tps-line tps out in cr cw total elapsed-s))
                    (ctx-notify (and ctx (extension-context-notify ctx)))
                   ) ;let
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
