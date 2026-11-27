;; rate-limited-sink-write-units!
;; 按语义单元计费写出文本。
;;
;; 语法
;; ----
;; (rate-limited-sink-write-units! sink text units)
;;
;; 参数
;; ----
;; sink : rate-limited-sink?
;; text : string
;; units : number
;; 计费数量：char 模式为字符数，block 模式为 1（每个结构片段）。
;;
;; 返回值
;; -----
;; unspecified；不限速时立即写出，限速时先按 units 等待额度再整段写出。

(import (scheme base) (liii check) (liii highlight output-rate))

(check-set-mode! 'report-failed)

;; 不限速：立即写出。
(let ((out (open-output-string)))
  (let ((sink (make-rate-limited-sink out)))
    (rate-limited-sink-write-units! sink "abc" 1)
    (check (get-output-string out) => "abc")
  ) ;let
) ;let

;; block 计费：每片段 1 单位，burst=2，第三个片段需等待。
(let* ((time-box (list 0.0))
       (sleeps '())
       (out (open-output-string))
       (sink
         (make-rate-limited-sink out
           :rate  1
           :burst 2
           :clock (lambda () (car time-box))
           :sleep-fn
           (lambda (s)
             (set! sleeps (cons s sleeps))
             (set-car! time-box (+ (car time-box) s))
           ) ;lambda
         ) ;make-rate-limited-sink
       ) ;sink
      ) ;
  (rate-limited-sink-write-units! sink "aaa" 1)
  (rate-limited-sink-write-units! sink "bbb" 1)
  (check (get-output-string out) => "aaabbb")
  (rate-limited-sink-write-units! sink "ccc" 1)
  (check (get-output-string out) => "aaabbbccc")
  (check (= (length sleeps) 1) => #t)
  (check
    (< (abs (- (car sleeps) 1.0)) 0.0001)
    =>
    #t
  ) ;check
) ;let*

;; 大于 burst 的语义单元也能完成：允许等待期间累加到 units，不死循环。
(let* ((time-box (list 0.0))
       (sleeps '())
       (out (open-output-string))
       (sink
         (make-rate-limited-sink out
           :rate  2
           :burst 2
           :clock (lambda () (car time-box))
           :sleep-fn
           (lambda (s)
             (set! sleeps (cons s sleeps))
             (set-car! time-box (+ (car time-box) s))
           ) ;lambda
         ) ;make-rate-limited-sink
       ) ;sink
      ) ;
  (rate-limited-sink-write-units! sink "abcdef" 6)
  (check (get-output-string out) => "abcdef")
  (check (= (length sleeps) 1) => #t)
  (check
    (< (abs (- (car sleeps) 2.0)) 0.0001)
    =>
    #t
  ) ;check
) ;let*

(check-report)
