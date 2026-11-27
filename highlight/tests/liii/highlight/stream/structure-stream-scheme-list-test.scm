;; structure-stream-scheme-list
;; scheme.json list 结构流集成测试：顶层 form 独立交付，嵌套 list 正确配对。
;;
;; 语法
;; ----
;; (make-structure-stream scheme-def emit-event)
;; (structure-stream-feed! stream chunk)
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; scheme-def : definition?
;; scheme 语法定义（含 list nested 结构）。
;;
;; chunk : string
;; 任意传输块。
;;
;; 返回值
;; -----
;; 事件通过回调交付；字符串、字符与注释中的括号不影响结构栈。

(import (scheme base)
  (liii check)
  (liii list)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(define scm-def (load-syntax-definition "scheme"))

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 两个顶层 form 分别交付；嵌套 list 自内向外闭合。
(let* ((c (make-collector))
       (s (make-structure-stream scm-def (car c)))
       (doc "(define (square x)\n  (* x x))\n\n(display (square 4))\n")
      ) ;
  (structure-stream-feed! s doc)
  (structure-stream-finish! s)
  (let* ((events ((cdr c)))
         (closes
           (filter (lambda (ev) (eq? (car ev) 'close)) events)
         ) ;closes
        ) ;
    (check (= (length closes) 5) => #t)
    ;; 最外层两个 form 的完整原文
    (check (list-ref (list-ref closes 2) 4) => "(define (square x)\n  (* x x))")
    (check (list-ref (list-ref closes 4) 4) => "(display (square 4))")
    (check (list-ref (car closes) 4) => "(square x)")
    (check (list-ref (cadr closes) 4) => "(* x x)")
  ) ;let*
) ;let*

;; 字符串中的括号不触发结构事件。
(let* ((c (make-collector)) (s (make-structure-stream scm-def (car c))))
  (structure-stream-feed! s "(display \"a(b)c\")\n")
  (structure-stream-finish! s)
  (let ((closes (filter (lambda (ev) (eq? (car ev) 'close)) ((cdr c)))))
    (check (= (length closes) 1) => #t)
    (check (list-ref (car closes) 4) => "(display \"a(b)c\")")
  ) ;let
) ;let*

;; 行注释中的括号不触发结构事件。
(let* ((c (make-collector)) (s (make-structure-stream scm-def (car c))))
  (structure-stream-feed! s "(+ 1 2) ; )(\n")
  (structure-stream-finish! s)
  (let ((closes (filter (lambda (ev) (eq? (car ev) 'close)) ((cdr c)))))
    (check (= (length closes) 1) => #t)
    (check (list-ref (car closes) 4) => "(+ 1 2)")
  ) ;let
) ;let*

;; 多行块注释中的括号不触发结构事件。
(let* ((c (make-collector)) (s (make-structure-stream scm-def (car c))))
  (structure-stream-feed! s "(f #| ) ( |# 1)\n")
  (structure-stream-finish! s)
  (let ((closes (filter (lambda (ev) (eq? (car ev) 'close)) ((cdr c)))))
    (check (= (length closes) 1) => #t)
    (check (list-ref (car closes) 4) => "(f #| ) ( |# 1)")
  ) ;let
) ;let*

;; 逐字符输入与整块输入事件一致。
(let* ((c1 (make-collector))
       (c2 (make-collector))
       (s1 (make-structure-stream scm-def (car c1)))
       (s2 (make-structure-stream scm-def (car c2)))
       (doc "(a (b \"c(d)\"))\n")
      ) ;
  (structure-stream-feed! s1 doc)
  (structure-stream-finish! s1)
  (for-each (lambda (ch) (structure-stream-feed! s2 (string ch)))
    (string->list doc)
  ) ;for-each
  (structure-stream-finish! s2)
  (check (map car ((cdr c1))) => (map car ((cdr c2))))
) ;let*

(check-report)
