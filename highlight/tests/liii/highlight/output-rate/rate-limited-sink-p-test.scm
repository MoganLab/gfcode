;; rate-limited-sink?
;; 判断对象是否为可调速输出 sink。
;;
;; 语法
;; ----
;; (rate-limited-sink? value)
;;
;; 参数
;; ----
;; value : any
;;
;; 返回值
;; -----
;; boolean

(import (scheme base) (liii check) (liii highlight output-rate))

(check-set-mode! 'report-failed)

(check-true (rate-limited-sink? (make-rate-limited-sink (open-output-string))))
(check-false (rate-limited-sink? '()))

(check-report)
