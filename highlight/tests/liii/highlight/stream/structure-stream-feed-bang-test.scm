;; structure-stream-feed!
;; 输入一个传输块，按语义结构产生事件。
;;
;; 语法
;; ----
;; (structure-stream-feed! stream chunk)
;;
;; 参数
;; ----
;; stream : structure-stream?
;; chunk : string
;; 任意传输块；块边界不构成结构边界。
;;
;; 返回值
;; -----
;; unspecified；事件通过构造时的回调交付。
;;
;; 错误处理
;; --------
;; structure-stream-error 当流已 finish!。
;;
;; 说明
;; ----
;; 事件形式：
;; (open name role metadata)
;; (content text spans)
;; (close name role closed? text)
;; (error reason detail)

(import (scheme base)
  (liii check)
  (liii json)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

;; 人工嵌套语法：( 打开 list，) 关闭 list。

(define list-def
  (parse-definition-json (string->json (string-append "{\"name\": \"L\", \"initial-context\": \"Base\","
                                         " \"contexts\": {\"Base\": {\"rules\": ["
                                         " {\"type\": \"DetectChar\", \"char\": \"(\", \"event\": \"list-open\"},"
                                         " {\"type\": \"DetectChar\", \"char\": \")\", \"event\": \"list-close\"}"
                                         " ]}},"
                                         " \"segments\": {\"structures\": [{\"name\": \"list\", \"role\": \"list\","
                                         "  \"scope\": \"nested\", \"begin\": \"list-open\", \"end\": \"list-close\"}]}}"
                                       ) ;string-append
                         ) ;string->json
  ) ;parse-definition-json
) ;define

;; 可变盒收集器：避免闭包捕获 let 绑定副本。

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 单块完整输入：open -> close，close 携带完整原文。
(let* ((c (make-collector)) (s (make-structure-stream list-def (car c))))
  (structure-stream-feed! s "(ab)")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (car (car events)) => 'open)
    (check (cadr (car events)) => "list")
    (check (car (cadr events)) => 'close)
    (check (list-ref (cadr events) 3) => #t)
    (check (list-ref (cadr events) 4) => "(ab)")
  ) ;let
) ;let*

;; 任意块边界：逐字符输入与整块输入事件一致。
(let* ((c (make-collector)) (s (make-structure-stream list-def (car c))))
  (for-each (lambda (ch) (structure-stream-feed! s (string ch)))
    (string->list "(a(b))")
  ) ;for-each
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open open close close))
    (check (list-ref (list-ref events 2) 4) => "(b)")
    (check (list-ref (list-ref events 3) 4) => "(a(b))")
  ) ;let
) ;let*

;; 不按块切分：块末尾不是结构边界，尾部暂存到真实行尾；
;; 行级语义（keyword/Int 右边界）不被块边界提前触发。
(let* ((c (make-collector)) (s (make-structure-stream list-def (car c))))
  (structure-stream-feed! s "(ab")
  (check ((cdr c)) => '())
  (structure-stream-feed! s "c)")
  (check ((cdr c)) => '())
  (structure-stream-feed! s "\n")
  (check (map car ((cdr c))) => '(open close content))
  (structure-stream-finish! s)
) ;let*

;; 顶层文本作为 content 事件。
(let* ((c (make-collector)) (s (make-structure-stream list-def (car c))))
  (structure-stream-feed! s "hi (x) bye")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(content open close content))
    (check (cadr (car events)) => "hi ")
    (check (cadr (list-ref events 3)) => " bye")
  ) ;let
) ;let*

;; 多余关闭：unexpected-close 错误，标记原文保留为 content。
(let* ((c (make-collector)) (s (make-structure-stream list-def (car c))))
  (structure-stream-feed! s ")")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(error content))
    (check (cadr (car events)) => 'unexpected-close)
    (check (cadr (cadr events)) => ")")
  ) ;let
) ;let*

;; 结束后继续 feed! 报错。
(let ((s (make-structure-stream list-def (lambda (ev) #f))))
  (structure-stream-finish! s)
  (check-catch 'structure-stream-error (structure-stream-feed! s "x"))
) ;let

(check-report)
