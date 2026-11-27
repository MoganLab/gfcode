;; structure-set-default
;; 获取未命中声明结构时的默认角色。
;;
;; 语法
;; ----
;; (structure-set-default structure-set)
;;
;; 参数
;; ----
;; structure-set : structure-set?
;;
;; 返回值
;; -----
;; symbol

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(check (structure-set-default (make-structure-set)) => 'text)

(check-report)
