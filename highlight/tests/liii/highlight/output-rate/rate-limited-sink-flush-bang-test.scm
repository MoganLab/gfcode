;; rate-limited-sink-flush!
;; 刷新输出端口。
;;
;; 语法
;; ----
;; (rate-limited-sink-flush! sink)
;;
;; 参数
;; ----
;; sink : rate-limited-sink?
;;
;; 返回值
;; -----
;; unspecified。

(import (scheme base) (liii check) (liii highlight output-rate))

(check-set-mode! 'report-failed)

(let ((sink (make-rate-limited-sink (open-output-string))))
  (rate-limited-sink-flush! sink)
  (check-true #t)
) ;let

(check-report)
