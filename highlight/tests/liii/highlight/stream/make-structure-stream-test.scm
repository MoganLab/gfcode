;; make-structure-stream
;; 构造结构事件流。
;;
;; 语法
;; ----
;; (make-structure-stream def emit-event)
;; (make-structure-stream def #f :line-sink on-line)
;; 展示模式每完成一行调用 (on-line text newline spans events)，不另建结构文本账本。
;;
;; 参数
;; ----
;; def : definition?
;; 携带 segments 结构声明的语法定义。
;;
;; emit-event : procedure
;; 事件回调，接收 (open ...) / (content ...) / (close ...) / (error ...) 列表。
;;
;; 返回值
;; -----
;; structure-stream?
;; 初始状态的结构流：空结构栈、无暂存、未结束。

(import (scheme base)
  (liii check)
  (liii json)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(define list-json
  (string-append "{\"name\": \"L\", \"initial-context\": \"Base\","
    " \"contexts\": {\"Base\": {\"rules\": ["
    " {\"type\": \"DetectChar\", \"char\": \"(\", \"event\": \"list-open\"},"
    " {\"type\": \"DetectChar\", \"char\": \")\", \"event\": \"list-close\"}"
    " ]}},"
    " \"segments\": {\"structures\": [{\"name\": \"list\", \"role\": \"list\","
    "  \"scope\": \"nested\", \"begin\": \"list-open\", \"end\": \"list-close\"}]}}"
  ) ;string-append
) ;define

(let* ((def (parse-definition-json (string->json list-json)))
       (stream (make-structure-stream def (lambda (ev) #f)))
      ) ;
  (check-true (structure-stream? stream))
  (check-false (structure-stream? def))
) ;let*

(check-report)
