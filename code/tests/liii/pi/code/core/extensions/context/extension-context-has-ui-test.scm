;; extension-context-has-ui
;; 读取扩展上下文是否处于有 UI 的环境。
;;
;; 语法
;; ----
;; (extension-context-has-ui ctx)
;;
;; 参数
;; ----
;; ctx : extension-context
;; 扩展上下文记录。
;;
;; 返回值
;; ----
;; any
;; 有 UI 时为真值，缺省为 #f。

(import (scheme base)
  (liii check)
  (liii check)
  (liii pi code core extensions context)
) ;import

(check-set-mode! 'report-failed)

(check-false (extension-context-has-ui (make-extension-context)))
(check-true (extension-context-has-ui (make-extension-context #f "." #f #f '() #f #t))
) ;check-true

(check-report)
