;; highlight-state?
;; 判断对象是否为高亮状态。
;;
;; 语法
;; ----
;; (highlight-state? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是高亮状态返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight highlighter))

(check-set-mode! 'report-failed)

(check-true (highlight-state? (make-highlight-state)))
(check-false (highlight-state? '("Level0")))
(check-false (highlight-state? "state"))
(check-false (highlight-state? #f))

(check-report)
