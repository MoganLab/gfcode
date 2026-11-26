;; make-match-result
;; 构造匹配结果对象。
;;
;; 语法
;; ----
;; (make-match-result)
;; (make-match-result matched? new-offset)
;;
;; 参数
;; ----
;; matched? : boolean (可选)
;; 是否匹配成功，默认 #f。
;;
;; new-offset : integer (可选)
;; 匹配后的新偏移，默认 0。
;;
;; 返回值
;; ----
;; <match-result>
;; 匹配结果对象。

(import (scheme base) (liii check) (liii highlight rule-matcher))

(check-set-mode! 'report-failed)

(let ((res (make-match-result)))
  (check (match-result-matched? res) => #f)
  (check (match-result-new-offset res) => 0)
) ;let

(let ((res (make-match-result #t 5)))
  (check (match-result-matched? res) => #t)
  (check (match-result-new-offset res) => 5)
) ;let

(check-report)
