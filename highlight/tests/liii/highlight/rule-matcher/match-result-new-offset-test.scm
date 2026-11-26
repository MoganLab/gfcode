;; match-result-new-offset
;; 读取匹配结果的新偏移。
;;
;; 语法
;; ----
;; (match-result-new-offset res)
;;
;; 参数
;; ----
;; res : match-result?
;; 匹配结果对象。
;;
;; 返回值
;; ----
;; integer
;; 匹配消费后的新偏移；未匹配时保持原偏移。

(import (scheme base) (liii check) (liii highlight rule-matcher))

(check-set-mode! 'report-failed)

(check (match-result-new-offset (make-match-result #t 7)) => 7)
(check (match-result-new-offset (make-match-result #f 0)) => 0)

(check-report)
