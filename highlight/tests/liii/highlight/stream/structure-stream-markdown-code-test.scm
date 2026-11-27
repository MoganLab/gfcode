;; structure-stream-markdown-code
;; markdown fenced code 结构流集成测试：开始/结束 fence 界定的多行结构。
;;
;; 语法
;; ----
;; (make-structure-stream md-def emit-event)
;; (structure-stream-feed! stream chunk)
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; md-def : definition?
;; markdown 语法定义（含 fenced-code delimited 结构）。
;;
;; chunk : string
;; 任意传输块。
;;
;; 返回值
;; -----
;; 事件通过回调交付；代码块完整归属一个 code-block，
;; 携带 language 元数据；代码内的 # 不产生标题；
;; EOF 未闭合代码块以 closed? = #f 交付。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(define md-def (load-syntax-definition "markdown"))

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 完整代码块：open -> close，close 携带含 fence 的完整原文与 language。
(let* ((c (make-collector))
       (s (make-structure-stream md-def (car c)))
       (doc "```scheme\n(define x 1)\n```\n")
      ) ;
  (structure-stream-feed! s doc)
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (cadr (car events)) => "fenced-code")
    (check (caddr (car events)) => 'code-block)
    (check (assoc 'language (cadddr (car events))) => '(language . "scheme"))
    (check (list-ref (cadr events) 3) => #t)
    (check (list-ref (cadr events) 4) => "```scheme\n(define x 1)\n```")
  ) ;let
) ;let*

;; 代码内的 # 不产生标题；标题与代码块交错。
(let* ((c (make-collector))
       (s (make-structure-stream md-def (car c)))
       (doc "# 示例\n```scheme\n# 不是标题\n(define x 1)\n```\n正文\n")
      ) ;
  (structure-stream-feed! s doc)
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content open close content))
    (check (cadr (car events)) => "heading-1")
    (check (cadr (list-ref events 3)) => "fenced-code")
    (check (list-ref (list-ref events 4) 4)
      =>
      "```scheme\n# 不是标题\n(define x 1)\n```"
    ) ;check
    (check (cadr (list-ref events 5)) => "\n正文\n")
  ) ;let
) ;let*

;; 逐字符输入与整块输入事件一致。
(let* ((c (make-collector))
       (s (make-structure-stream md-def (car c)))
       (doc "~~~lua\nprint(1)\n~~~\n")
      ) ;
  (for-each (lambda (ch) (structure-stream-feed! s (string ch)))
    (string->list doc)
  ) ;for-each
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (assoc 'language (cadddr (car events))) => '(language . "lua"))
    (check (list-ref (cadr events) 4) => "~~~lua\nprint(1)\n~~~")
  ) ;let
) ;let*

;; EOF 未闭合代码块：closed? = #f，原文不丢失。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "```scheme\n(define x 1)\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close))
    (check (list-ref (cadr events) 3) => #f)
    (check (list-ref (cadr events) 4) => "```scheme\n(define x 1)\n")
  ) ;let
) ;let*

;; 无语言标注的代码块：无 language 元数据。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "```\ncode\n```\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (assoc 'language (cadddr (car events))) => #f)
  ) ;let
) ;let*

(check-report)
