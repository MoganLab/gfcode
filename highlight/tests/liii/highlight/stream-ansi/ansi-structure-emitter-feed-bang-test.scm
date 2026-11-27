;; ansi-structure-emitter-feed!
;; 把结构流原文账本的新增完整行渲染为 ANSI 并输出。
;;
;; 语法
;; ----
;; (ansi-structure-emitter-feed! emitter stream event)
;; (ansi-structure-emitter-feed! emitter stream event final?)
;;
;; 参数
;; ----
;; emitter : ansi-structure-emitter?
;; stream : structure-stream?
;; event : list
;; final? : boolean (可选)
;; #t 时连不完整尾行一起渲染（EOF），不补换行。
;;
;; 返回值
;; -----
;; unspecified；只渲染完整行，不完整尾行留待后续，
;; 避免在行中切断关键字/标识符。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight theme)
  (liii highlight tui-render)
  (liii highlight stream)
  (liii highlight stream-ansi)
) ;import

(check-set-mode! 'report-failed)

(let* ((def (load-syntax-definition "scheme"))
       (th (default-breeze-dark-theme))
       (out (open-output-string))
       (e (make-ansi-structure-emitter def th (lambda (t) (display t out))))
       (box (list #f))
       (s
         (make-structure-stream def
           (lambda (ev) (ansi-structure-emitter-feed! e (car box) ev))
         ) ;make-structure-stream
       ) ;s
       (doc "(define x 42)\n")
      ) ;
  (set-car! box s)
  (structure-stream-feed! s doc)
  (ansi-structure-emitter-feed! e s '(eof) #t)
  (check (get-output-string out) => (highlight-text-to-ansi doc def th))
) ;let*

(check-report)
