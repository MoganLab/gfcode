;; structure-stream-json-container
;; json.json object/array 结构流集成测试：嵌套容器正确配对。
;;
;; 语法
;; ----
;; (make-structure-stream json-def emit-event)
;; (structure-stream-feed! stream chunk)
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; json-def : definition?
;; json 语法定义（含 object/array nested 结构）。
;;
;; chunk : string
;; 任意传输块。
;;
;; 返回值
;; -----
;; 事件通过回调交付；字符串与转义中的括号不触发结构事件；
;; EOF 未闭合容器报 unexpected-eof 并以 closed? = #f 交付。

(import (scheme base)
  (liii check)
  (liii list)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(define json-def (load-syntax-definition "json"))

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 嵌套 object/array：根对象完整交付，内层自内向外闭合。
(let* ((c (make-collector))
       (s (make-structure-stream json-def (car c)))
       (doc "{\"deps\": [{\"name\": \"highlight\"}], \"n\": 1}\n")
      ) ;
  (structure-stream-feed! s doc)
  (structure-stream-finish! s)
  (let* ((events ((cdr c)))
         (closes
           (filter (lambda (ev) (eq? (car ev) 'close)) events)
         ) ;closes
        ) ;
    (check (= (length closes) 3) => #t)
    (check (cadr (car closes)) => "object")
    (check (list-ref (car closes) 4) => "{\"name\": \"highlight\"}")
    (check (cadr (cadr closes)) => "array")
    (check (list-ref (cadr closes) 4) => "[{\"name\": \"highlight\"}]")
    (check (list-ref (list-ref closes 2) 4)
      =>
      "{\"deps\": [{\"name\": \"highlight\"}], \"n\": 1}"
    ) ;check
    (check (list-ref (list-ref closes 2) 3) => #t)
  ) ;let*
) ;let*

;; 字符串与转义中的括号不触发结构事件。
(let* ((c (make-collector)) (s (make-structure-stream json-def (car c))))
  (structure-stream-feed! s "{\"k\": \"a{b}[c]\\\"d\"}\n")
  (structure-stream-finish! s)
  (let ((closes (filter (lambda (ev) (eq? (car ev) 'close)) ((cdr c)))))
    (check (= (length closes) 1) => #t)
    (check (list-ref (car closes) 4) => "{\"k\": \"a{b}[c]\\\"d\"}")
  ) ;let
) ;let*

;; EOF 未闭合容器：unexpected-eof + closed? = #f。
(let* ((c (make-collector)) (s (make-structure-stream json-def (car c))))
  (structure-stream-feed! s "{\"a\": [1, 2")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open open error close error close))
    (check (cadr (list-ref events 2)) => 'unexpected-eof)
    (check (list-ref (list-ref events 3) 3) => #f)
    (check (list-ref (list-ref events 5) 3) => #f)
  ) ;let
) ;let*

;; 逐字符输入与整块输入事件一致。
(let* ((c1 (make-collector))
       (c2 (make-collector))
       (s1 (make-structure-stream json-def (car c1)))
       (s2 (make-structure-stream json-def (car c2)))
       (doc "[{\"a\": 1}, [2, 3]]\n")
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
