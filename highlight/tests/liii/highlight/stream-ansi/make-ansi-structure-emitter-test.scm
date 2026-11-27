;; make-ansi-structure-emitter
;; 构造结构事件到 ANSI 文本的适配器。
;;
;; 语法
;; ----
;; (make-ansi-structure-emitter def th emit-text)
;;
;; 参数
;; ----
;; def : definition?
;; th : theme?
;; emit-text : procedure
;; 接收 ANSI 字符串的回调。
;;
;; 返回值
;; -----
;; ansi-structure-emitter?
;; 已渲染位置为 0、渲染状态为初始高亮状态。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight theme)
  (liii highlight stream-ansi)
) ;import

(check-set-mode! 'report-failed)

(let* ((def (load-syntax-definition "scheme"))
       (th (default-breeze-dark-theme))
       (e (make-ansi-structure-emitter def th (lambda (t) #f)))
      ) ;
  (check-true (ansi-structure-emitter? e))
  (check-false (ansi-structure-emitter? def))
) ;let*

(check-report)
