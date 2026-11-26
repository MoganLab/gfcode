;; match-result-matched?
;; 读取匹配结果是否成功。
;;
;; 语法
;; ----
;; (match-result-matched? res)
;;
;; 参数
;; ----
;; res : match-result?
;; 匹配结果对象。
;;
;; 返回值
;; ----
;; boolean
;; 匹配成功返回 #t。

(import (scheme base) (liii check) (liii highlight rule-matcher))

(check-set-mode! 'report-failed)

(check-true (match-result-matched? (make-match-result #t 1)))
(check-false (match-result-matched? (make-match-result #f 0)))

(check-report)
