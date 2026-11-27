;; structure-stream-finish!
;; EOF 收尾：提交暂存尾部并按策略关闭未闭合结构。
;;
;; 语法
;; ----
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; stream : structure-stream?
;;
;; 返回值
;; -----
;; unspecified；幂等，重复调用不产生额外事件。
;;
;; 说明
;; ----
;; line 结构在 EOF 正常闭合（closed? = #t）。
;; emit-unclosed：交付未闭合结构（closed? = #f）。
;; error-and-emit：先报 unexpected-eof 错误再交付未闭合结构。

(import (scheme base)
  (liii check)
  (liii json)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

;; 人工单行语法：@@ 打开 line 结构，真实行尾闭合。

(define line-def
  (parse-definition-json (string->json (string-append "{\"name\": \"H\", \"initial-context\": \"Base\","
                                         " \"contexts\": {\"Base\": {\"rules\": ["
                                         " {\"type\": \"StringDetect\", \"String\": \"@@ \", \"event\": \"head-open\","
                                         "  \"first-non-space\": true}" " ]}},"
                                         " \"segments\": {\"structures\": [{\"name\": \"head\", \"role\": \"heading\","
                                         "  \"scope\": \"line\", \"begin\": \"head-open\"}]}}"
                                       ) ;string-append
                         ) ;string->json
  ) ;parse-definition-json
) ;define

(define nested-def
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

(define strict-def
  (parse-definition-json (string->json (string-append "{\"name\": \"S\", \"initial-context\": \"Base\","
                                         " \"contexts\": {\"Base\": {\"rules\": ["
                                         " {\"type\": \"DetectChar\", \"char\": \"(\", \"event\": \"list-open\"},"
                                         " {\"type\": \"DetectChar\", \"char\": \")\", \"event\": \"list-close\"}"
                                         " ]}},"
                                         " \"segments\": {\"structures\": [{\"name\": \"list\", \"role\": \"list\","
                                         "  \"scope\": \"nested\", \"begin\": \"list-open\", \"end\": \"list-close\","
                                         "  \"on-eof\": \"error-and-emit\"}]}}"
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

;; EOF 提交无换行尾部；line 结构正常闭合。
(let* ((c (make-collector)) (s (make-structure-stream line-def (car c))))
  (structure-stream-feed! s "@@ title")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close))
    (check (list-ref (cadr events) 3) => #t)
    (check (list-ref (cadr events) 4) => "@@ title")
  ) ;let
) ;let*

;; 真实行尾闭合 line 结构，换行符归入 content。
(let* ((c (make-collector)) (s (make-structure-stream line-def (car c))))
  (structure-stream-feed! s "@@ a\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (list-ref (cadr events) 4) => "@@ a")
    (check (cadr (list-ref events 2)) => "\n")
  ) ;let
) ;let*

;; 开始标记前缀跨块：@ 在块末尾时暂存，不误判为正文；
;; 尾部统一暂存到行尾/EOF，open 在行尾或 EOF 时交付。
(let* ((c (make-collector)) (s (make-structure-stream line-def (car c))))
  (structure-stream-feed! s "@")
  (check ((cdr c)) => '())
  (structure-stream-feed! s "@ x")
  (check ((cdr c)) => '())
  (structure-stream-finish! s)
  (check (map car ((cdr c))) => '(open close))
  (check
    (list-ref
      (car (reverse ((cdr c))))
      4
    ) ;list-ref
    =>
    "@@ x"
  ) ;check
) ;let*

;; emit-unclosed：EOF 交付未闭合嵌套结构。
(let* ((c (make-collector)) (s (make-structure-stream nested-def (car c))))
  (structure-stream-feed! s "(ab")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close))
    (check (list-ref (cadr events) 3) => #f)
    (check (list-ref (cadr events) 4) => "(ab")
  ) ;let
) ;let*

;; error-and-emit：先 unexpected-eof 再未闭合 close。
(let* ((c (make-collector)) (s (make-structure-stream strict-def (car c))))
  (structure-stream-feed! s "(ab")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open error close))
    (check (cadr (cadr events)) => 'unexpected-eof)
    (check (list-ref (list-ref events 2) 3) => #f)
  ) ;let
) ;let*

;; finish! 幂等：重复调用不追加事件；空输入不产生虚假片段。
(let* ((c (make-collector)) (s (make-structure-stream nested-def (car c))))
  (structure-stream-finish! s)
  (structure-stream-finish! s)
  (check ((cdr c)) => '())
) ;let*

(check-report)
