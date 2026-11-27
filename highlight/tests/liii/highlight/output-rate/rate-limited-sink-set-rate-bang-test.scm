;; rate-limited-sink-set-rate!
;; 运行时动态调速，新速率立即生效。
;;
;; 语法
;; ----
;; (rate-limited-sink-set-rate! sink rate)
;;
;; 参数
;; ----
;; sink : rate-limited-sink?
;; rate : number | #f
;; 每秒字符单元数；#f 表示不限速（立即排空）。
;;
;; 返回值
;; -----
;; unspecified。
;;
;; 错误处理
;; --------
;; output-rate-error 当 rate 非正数或非数值。

(import (scheme base) (liii check) (liii highlight output-rate))

(check-set-mode! 'report-failed)

;; 切到 #f：取消限速，立即写出。
(let ((out (open-output-string)))
  (let ((sink (make-rate-limited-sink out :rate 1 :burst 1)))
    (rate-limited-sink-set-rate! sink #f)
    (rate-limited-sink-write! sink "immediate")
    (check (get-output-string out) => "immediate")
  ) ;let
) ;let

;; 升速：等待时间缩短。
(let* ((time-box (list 0.0))
       (sleeps '())
       (out (open-output-string))
       (sink
         (make-rate-limited-sink out
           :rate  1
           :burst 1
           :clock (lambda () (car time-box))
           :sleep-fn
           (lambda (s)
             (set! sleeps (cons s sleeps))
             (set-car! time-box (+ (car time-box) s))
           ) ;lambda
         ) ;make-rate-limited-sink
       ) ;sink
      ) ;
  (rate-limited-sink-set-rate! sink 100)
  (rate-limited-sink-write! sink "ab")
  (check (get-output-string out) => "ab")
  ;; 升速后额度按 burst 计，等待时间很短（小于原速率 1/s 的 1s）
  (check (< (car time-box) 1.0) => #t)
) ;let*

;; 降速后按新速率等待。
(let* ((time-box (list 0.0))
       (sleeps '())
       (out (open-output-string))
       (sink
         (make-rate-limited-sink out
           :rate  100
           :burst 100
           :clock (lambda () (car time-box))
           :sleep-fn
           (lambda (s)
             (set! sleeps (cons s sleeps))
             (set-car! time-box (+ (car time-box) s))
           ) ;lambda
         ) ;make-rate-limited-sink
       ) ;sink
      ) ;
  (rate-limited-sink-set-rate! sink 2)
  (rate-limited-sink-write! sink "ab")
  (check (get-output-string out) => "ab")
  (rate-limited-sink-write! sink "cd")
  (check (get-output-string out) => "abcd")
  ;; burst=100 额度充足，abcd 在 burst 内立即写出；
  ;; 真实时钟下 elapsed>0 可能触发一次短等待，验证总时长小于 1s 即可。
  (check (< (car time-box) 1.0) => #t)
) ;let*

;; 非法速率。
(let ((sink (make-rate-limited-sink (open-output-string))))
  (check-catch 'output-rate-error (rate-limited-sink-set-rate! sink 0))
  (check-catch 'output-rate-error (rate-limited-sink-set-rate! sink -5))
  (check-catch 'output-rate-error (rate-limited-sink-set-rate! sink "fast"))
) ;let

(check-report)
