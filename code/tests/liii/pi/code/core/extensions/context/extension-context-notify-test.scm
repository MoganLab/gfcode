;; extension-context-notify
;; 读取扩展上下文中 arm 的通知回调。
;;
;; 语法
;; ----
;; (extension-context-notify ctx)
;;
;; 参数
;; ----
;; ctx : extension-context
;; 扩展上下文记录。
;;
;; 返回值
;; ----
;; procedure or #f
;; 通知回调过程，缺省为 #f。

(import (scheme base)
  (liii check)
  (liii check)
  (liii pi code core extensions context)
) ;import

(check-set-mode! 'report-failed)

(define (noop-notify msg)
  #t
) ;define
(check (extension-context-notify (make-extension-context)) => #f)
(check (extension-context-notify (make-extension-context #f "." #f #f '() noop-notify))
  =>
  noop-notify
) ;check

(check-report)
