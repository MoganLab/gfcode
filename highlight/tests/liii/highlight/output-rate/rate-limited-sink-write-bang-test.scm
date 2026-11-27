;; rate-limited-sink-write!
;; 按当前速率输出文本，每批之间检查最新速率。
;;
;; 语法
;; ----
;; (rate-limited-sink-write! sink text)
;;
;; 参数
;; ----
;; sink : rate-limited-sink?
;; text : string
;;
;; 返回值
;; -----
;; unspecified；文本原样写入输出端口，只改变时间节奏。
;;
;; 说明
;; ----
;; 虚拟时钟下可验证固定速率、burst 与动态调速；
;; 不限速时立即写出全部文本。

(import (scheme base) (liii check) (liii highlight output-rate))

(check-set-mode! 'report-failed)

;; 虚拟时钟环境：clock 读时间盒，sleep 推进时间并记录。

(define (make-env rate burst)
  (let* ((time-box (list 0.0))
         (sleeps '())
         (out (open-output-string))
         (sink
           (make-rate-limited-sink out
             :rate  rate
             :burst burst
             :clock (lambda () (car time-box))
             :sleep-fn
             (lambda (s)
               (set! sleeps (cons s sleeps))
               (set-car! time-box (+ (car time-box) s))
             ) ;lambda
           ) ;make-rate-limited-sink
         ) ;sink
        ) ;
    (list sink out time-box (lambda () (reverse sleeps)))
  ) ;let*
) ;define

;; 不限速：立即全部写出。
(let ((out (open-output-string)))
  (let ((sink (make-rate-limited-sink out)))
    (rate-limited-sink-write! sink "hello")
    (check (get-output-string out) => "hello")
  ) ;let
) ;let

;; burst 内立即写出；超出后按速率等待。
(let* ((env (make-env 10 4))
       (sink (car env))
       (out (cadr env))
       (get-sleeps (cadddr env))
      ) ;
  (rate-limited-sink-write! sink "ab")
  (check (get-output-string out) => "ab")
  (check (get-sleeps) => '())
  (rate-limited-sink-write! sink "cdef")
  ;; 剩 2 个令牌，cd 立即，ef 各需 0.1s
  (check (get-output-string out) => "abcdef")
  (let ((sleeps (get-sleeps)))
    (check (= (length sleeps) 2) => #t)
    (check
      (< (abs (- (car sleeps) 0.1)) 0.0001)
      =>
      #t
    ) ;check
  ) ;let
) ;let*

;; 固定速率节奏：burst=2，rate=4，写 6 字符需等待。
(let* ((env (make-env 4 2))
       (sink (car env))
       (out (cadr env))
       (get-sleeps (cadddr env))
      ) ;
  (rate-limited-sink-write! sink "abcdef")
  (check (get-output-string out) => "abcdef")
  (check (> (length (get-sleeps)) 0) => #t)
) ;let*

;; 低速分批时不切断 ANSI SGR 转义序列。
(let* ((time-box (list 0.0))
       (outputs-at-sleep '())
       (out (open-output-string))
       (sink
         (make-rate-limited-sink out
           :rate  1
           :burst 1
           :clock (lambda () (car time-box))
           :sleep-fn
           (lambda (s)
             (set! outputs-at-sleep (cons (get-output-string out) outputs-at-sleep))
             (set-car! time-box (+ (car time-box) s))
           ) ;lambda
         ) ;make-rate-limited-sink
       ) ;sink
      ) ;
  (rate-limited-sink-write! sink "\x1b;[31mA\x1b;[0mB")
  (check (get-output-string out) => "\x1b;[31mA\x1b;[0mB")
  ;; 第一次等待前必须已经写出完整颜色前缀，而不是单独的 ESC。
  (check (car (reverse outputs-at-sleep)) => "\x1b;[31m")
) ;let*

(check-report)
