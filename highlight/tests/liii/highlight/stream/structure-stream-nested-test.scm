;; structure-stream-nested
;; 通用嵌套分隔符结构集成测试：递归节点、类型不匹配与容错。
;;
;; 语法
;; ----
;; (make-structure-stream def emit-event)
;; (structure-stream-feed! stream chunk)
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; def : definition?
;; 含嵌套结构声明的人工语法。
;;
;; chunk : string
;; 任意传输块。
;;
;; 返回值
;; -----
;; 事件通过回调交付；嵌套 open/close 正确配对，
;; 类型不匹配报 mismatched-delimiter 且不弹栈，原文不丢失。

(import (scheme base)
  (liii check)
  (liii json)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

;; 两种嵌套结构：list 用 ()，block 用 {}，结束事件不同。

(define mixed-def
  (parse-definition-json (string->json (string-append "{\"name\": \"M\", \"initial-context\": \"Base\","
                                         " \"contexts\": {\"Base\": {\"rules\": ["
                                         " {\"type\": \"DetectChar\", \"char\": \"(\", \"event\": \"list-open\"},"
                                         " {\"type\": \"DetectChar\", \"char\": \")\", \"event\": \"list-close\"},"
                                         " {\"type\": \"DetectChar\", \"char\": \"{\", \"event\": \"block-open\"},"
                                         " {\"type\": \"DetectChar\", \"char\": \"}\", \"event\": \"block-close\"}"
                                         " ]}},"
                                         " \"segments\": {\"structures\": ["
                                         " {\"name\": \"list\", \"role\": \"list\", \"scope\": \"nested\","
                                         "  \"begin\": \"list-open\", \"end\": \"list-close\", \"children\": [\"list\", \"block\"]},"
                                         " {\"name\": \"block\", \"role\": \"block\", \"scope\": \"nested\","
                                         "  \"begin\": \"block-open\", \"end\": \"block-close\", \"children\": [\"list\", \"block\"]}"
                                         " ]}}"
                                       ) ;string-append
                         ) ;string->json
  ) ;parse-definition-json
) ;define

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 深度嵌套：三层 list 自内向外闭合，原文逐层完整。
(let* ((c (make-collector)) (s (make-structure-stream mixed-def (car c))))
  (structure-stream-feed! s "(a(b(c)))\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open open open close close close content))
    (check (list-ref (list-ref events 3) 4) => "(c)")
    (check (list-ref (list-ref events 4) 4) => "(b(c))")
    (check (list-ref (list-ref events 5) 4) => "(a(b(c)))")
  ) ;let
) ;let*

;; 异类嵌套：list 内含 block，各自正确配对。
(let* ((c (make-collector)) (s (make-structure-stream mixed-def (car c))))
  (structure-stream-feed! s "(a{b})\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open open close close content))
    (check (cadr (list-ref events 2)) => "block")
    (check (list-ref (list-ref events 2) 4) => "{b}")
    (check (cadr (list-ref events 3)) => "list")
    (check (list-ref (list-ref events 3) 4) => "(a{b})")
  ) ;let
) ;let*

;; 类型不匹配：( 打开后遇 } 报 mismatched-delimiter，不弹栈；
;; 后续 ) 仍正常闭合，原文不丢失。
(let* ((c (make-collector)) (s (make-structure-stream mixed-def (car c))))
  (structure-stream-feed! s "(a}b)\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open error close content))
    (check (cadr (cadr events)) => 'mismatched-delimiter)
    (check (list-ref (list-ref events 2) 3) => #t)
    (check (list-ref (list-ref events 2) 4) => "(a}b)")
  ) ;let
) ;let*

;; 逐字符输入与整块输入事件一致（嵌套 + 不匹配）。
(let* ((c1 (make-collector))
       (c2 (make-collector))
       (s1 (make-structure-stream mixed-def (car c1)))
       (s2 (make-structure-stream mixed-def (car c2)))
       (doc "(a{b(c})\n")
      ) ;
  (structure-stream-feed! s1 doc)
  (structure-stream-finish! s1)
  (for-each (lambda (ch) (structure-stream-feed! s2 (string ch)))
    (string->list doc)
  ) ;for-each
  (structure-stream-finish! s2)
  (check (map car ((cdr c1))) => (map car ((cdr c2))))
  (check
    (map
      (lambda (ev) (if (eq? (car ev) 'close) (list-ref ev 4) #f))
      ((cdr c1))
    ) ;map
    =>
    (map
      (lambda (ev) (if (eq? (car ev) 'close) (list-ref ev 4) #f))
      ((cdr c2))
    ) ;map
  ) ;check
) ;let*

(check-report)
