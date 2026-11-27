;; structure-set-root-scope
;; 获取根消费视图。
;;
;; 语法
;; ----
;; (structure-set-root-scope structure-set)
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
(check (structure-set-root-scope (make-structure-set :root-scope 'value))
  =>
  'value
) ;check

(check-report)
