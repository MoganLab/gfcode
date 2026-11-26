;; pi-execute-tool-calls
;; 批量顺序执行工具调用列表，并返回所有工具调用的结果消息列表。
;; 本函数是 pi-execute-tool-calls-with-status 的薄包装，丢弃批次终止标记。
;;
;; 语法
;; ----
;; (pi-execute-tool-calls tool-calls emit timeout (opt-config #f))
;;
;; 参数
;; ----
;; tool-calls : list?，待执行的工具调用块列表。
;; emit : (or procedure? #f)，事件派发过程。
;; timeout : real?，工具执行超时时间（秒）。
;; opt-config : (or list? #f)，可选的 Agent 配置 alist。
;;
;; 返回值
;; ----
;; list?，工具执行结果消息（pi-tool-result-message）列表。

(import (scheme base)
  (liii check)
  (liii string)
  (liii pi agent tools)
  (liii pi ai message)
  (liii pi ai tools result)
) ;import

(check-set-mode! 'report-failed)

;; 1. 批量执行：返回所有结果消息，顺序与调用一致
(let* ((mock-exec (lambda (name args . opts) (pi-tool-result (string-append "res:" name) #f))
       ) ;mock-exec
       (cfg (list (cons 'execute-tool-call mock-exec)))
       (calls (list '((id . "c1") (name . "toolA") (arguments))
                '((id . "c2") (name . "toolB") (arguments))
              ) ;list
       ) ;calls
       (msgs (pi-execute-tool-calls calls #f 10 cfg))
      ) ;
  (check (length msgs) => 2)
  (check-true (pi-tool-result-message? (car msgs)))
  (check (pi-tool-result-message-tool-name (car msgs)) => "toolA")
  (check (pi-tool-result-message-tool-name (cadr msgs)) => "toolB")
  (check
    (pi-text-block-text (car (pi-tool-result-message-content (car msgs))))
    =>
    "res:toolA"
  ) ;check
) ;let*

;; 2. 传递 opt-config 时正常批量执行
(let* ((mock-exec (lambda (name args . opts) (pi-tool-result "cfg-ok" #f)))
       (cfg (list (cons 'execute-tool-call mock-exec) (cons 'provider "google")))
       (calls (list '((id . "c1") (name . "toolA") (arguments))))
       (msgs (pi-execute-tool-calls calls #f 10 cfg))
      ) ;
  (check (length msgs) => 1)
  (check
    (pi-text-block-text (car (pi-tool-result-message-content (car msgs))))
    =>
    "cfg-ok"
  ) ;check
) ;let*

(check-report)
