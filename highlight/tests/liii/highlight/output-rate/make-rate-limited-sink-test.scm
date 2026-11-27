;; make-rate-limited-sink
;; 构造可调速输出 sink。
;;
;; 语法
;; ----
;; (make-rate-limited-sink out [rate] [burst] [clock] [sleep-fn])
;;
;; 参数
;; ----
;; out : output-port?
;; rate : number | #f (可选)
;; 每秒输出的字符单元数；#f 表示不限速。
;;
;; burst : integer (可选，默认 80)
;; 桶容量（瞬时允许的输出量）。
;;
;; clock : procedure (可选)
;; 返回当前时间（秒）的函数，可注入虚拟时钟。
;;
;; sleep-fn : procedure (可选)
;; 睡眠函数，参数为秒数，可注入。
;;
;; 返回值
;; -----
;; rate-limited-sink?
;; 初始不限速、无输出的 sink。

(import (scheme base) (liii check) (liii highlight output-rate))

(check-set-mode! 'report-failed)

(let ((sink (make-rate-limited-sink (open-output-string))))
  (check-true (rate-limited-sink? sink))
  (check-false (rate-limited-sink? '()))
) ;let

;; 关键字参数：rate / burst / clock / sleep-fn
(let* ((time-box (list 0))
       (sink (make-rate-limited-sink (open-output-string)
               :rate     10
               :burst    4
               :clock    (lambda () (car time-box))
               :sleep-fn (lambda (s) #f)
             ) ;make-rate-limited-sink
       ) ;sink
      ) ;
  (check-true (rate-limited-sink? sink))
) ;let*

(check-report)
