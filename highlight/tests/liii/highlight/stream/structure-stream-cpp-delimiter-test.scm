;; structure-stream-cpp-delimiter
;; cpp.json 通用括号结构流集成测试：brace/paren/bracket 嵌套树。
;;
;; 语法
;; ----
;; (make-structure-stream cpp-def emit-event)
;; (structure-stream-feed! stream chunk)
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; cpp-def : definition?
;; C++ 语法定义（含 brace/paren/bracket nested 结构）。
;;
;; chunk : string
;; 任意传输块。
;;
;; 返回值
;; -----
;; 事件通过回调交付；字符串、字符、raw string 与注释中的括号
;; 不影响结构栈；本阶段不识别 function/class 声明语义。

(import (scheme base)
  (liii check)
  (liii list)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(define cpp-def (load-syntax-definition "cpp"))

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 函数体 brace 内含初始化列表 brace：两者都是通用 brace 结构。
(let* ((c (make-collector))
       (s (make-structure-stream cpp-def (car c)))
       (doc "void f() {\n  int v[] = {1, 2};\n}\n")
      ) ;
  (structure-stream-feed! s doc)
  (structure-stream-finish! s)
  (let* ((events ((cdr c)))
         (closes
           (filter (lambda (ev) (eq? (car ev) 'close)) events)
         ) ;closes
         (names (map cadr closes))
        ) ;
    (check (member "paren" names) => '("paren" "bracket" "brace" "brace"))
    (check (= (length closes) 4) => #t)
    ;; 最外层 brace 完整原文
    (check (list-ref (list-ref closes 3) 4) => "{\n  int v[] = {1, 2};\n}")
    ;; 初始化列表是 brace，不是函数体
    (check (list-ref (list-ref closes 2) 4) => "{1, 2}")
  ) ;let*
) ;let*

;; 字符串、字符、注释中的括号不触发结构事件。
(let* ((c (make-collector))
       (s (make-structure-stream cpp-def (car c)))
       (doc "f(\"a(b\", '{', R\"(x{y)z)\"); // }{\n")
      ) ;
  (structure-stream-feed! s doc)
  (structure-stream-finish! s)
  (let ((closes (filter (lambda (ev) (eq? (car ev) 'close)) ((cdr c)))))
    (check (= (length closes) 1) => #t)
    (check (cadr (car closes)) => "paren")
  ) ;let
) ;let*

;; 块注释中的括号不触发结构事件。
(let* ((c (make-collector)) (s (make-structure-stream cpp-def (car c))))
  (structure-stream-feed! s "int a; /* { ( [ */ int b;\n")
  (structure-stream-finish! s)
  (let ((closes (filter (lambda (ev) (eq? (car ev) 'close)) ((cdr c)))))
    (check closes => '())
  ) ;let
) ;let*

;; 逐字符输入与整块输入事件一致。
(let* ((c1 (make-collector))
       (c2 (make-collector))
       (s1 (make-structure-stream cpp-def (car c1)))
       (s2 (make-structure-stream cpp-def (car c2)))
       (doc "if (a[0]) { g(); }\n")
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
