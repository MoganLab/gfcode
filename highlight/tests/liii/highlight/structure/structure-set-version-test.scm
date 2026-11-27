;; structure-set-version
;; 获取结构 Schema 版本。
;;
;; 语法
;; ----
;; (structure-set-version structure-set)
;;
;; 参数
;; ----
;; structure-set : structure-set?
;;
;; 返回值
;; -----
;; integer

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-set-version (make-structure-set)) => 1)

(check-report)
