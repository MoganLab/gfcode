;; highlight-line-events
;; 高亮单行并收集结构事件。
;;
;; 语法
;; ----
;; (highlight-line-events text state def)
;;
;; 参数
;; ----
;; text : string
;; 单行文本（不含换行符）。
;;
;; state : highlight-state?
;; 上一行的高亮状态。
;;
;; def : definition?
;; 语法定义；规则可声明 event。
;;
;; 返回值
;; -----
;; (values spans next-state events)
;; spans / next-state 与 highlight-line 一致；
;; events 为 '((event-name start-offset end-offset) ...)，按发生顺序。
;; 无事件规则的语法返回空列表，高亮行为不变。

(import (scheme base)
  (liii check)
  (liii json)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

(let* ((raw (string->json (string-append "{\"name\": \"L\", \"initial-context\": \"Base\","
                            " \"contexts\": {\"Base\": {\"rules\": ["
                            " {\"type\": \"DetectChar\", \"char\": \"(\", \"event\": \"list-open\"},"
                            " {\"type\": \"DetectChar\", \"char\": \")\", \"event\": \"list-close\"},"
                            " {\"type\": \"DetectIdentifier\", \"attribute\": \"Normal\"}]}},"
                            " \"segments\": {\"structures\": [{\"name\": \"list\", \"role\": \"list\","
                            "  \"scope\": \"nested\", \"begin\": \"list-open\", \"end\": \"list-close\"}]}}"
                          ) ;string-append
            ) ;string->json
       ) ;raw
       (def (parse-definition-json raw))
       (state (initial-highlight-state def))
      ) ;
  (let-values (((spans next-state events) (highlight-line-events "(ab)" state def)))
    (check events => '(("list-open" 0 1 ()) ("list-close" 3 4 ())))
    (let-values (((spans2 next-state2) (highlight-line "(ab)" state def)))
      (check spans => spans2)
      (check (highlight-state-stack next-state)
        =>
        (highlight-state-stack next-state2)
      ) ;check
    ) ;let-values
  ) ;let-values
) ;let*

;; 声明了事件但未命中的语法：events 为空。
(let* ((def (load-syntax-definition "scheme")) (state (initial-highlight-state def)))
  (let-values (((spans next-state events) (highlight-line-events "x 1" state def)))
    (check events => '())
  ) ;let-values
) ;let*

(check-report)
