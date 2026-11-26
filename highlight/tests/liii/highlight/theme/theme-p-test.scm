;; theme?
;; 判断对象是否为主题。
;;
;; 语法
;; ----
;; (theme? obj)
;;
;; 参数
;; ----
;; obj : any
;; 待判断的对象。
;;
;; 返回值
;; ----
;; boolean
;; 是主题返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check-true (theme? (make-theme)))
(check-true (theme? (default-breeze-dark-theme)))
(check-false (theme? "Breeze Dark"))
(check-false (theme? (make-style-entry)))
(check-false (theme? #f))

(check-report)
