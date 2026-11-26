;; pi-execute-one-tool-call
;; 执行单个工具调用并返回工具结果消息。
;; 本函数是 pi-execute-one-tool-call-with-status 的薄包装，仅取结果消息。
;;
;; 语法
;; ----
;; (pi-execute-one-tool-call call emit timeout (opt-config #f))
;;
;; 参数
;; ----
;; call : list?，包含 id, name, arguments 的工具调用 alist。
;; emit : (or procedure? #f)，事件派发过程。
;; timeout : real?，工具执行超时时间（秒）。
;; opt-config : (or list? #f)，可选的 Agent 配置 alist。
;;
;; 返回值
;; ----
;; pi-tool-result-message?，工具执行结果消息对象。

(import (scheme base)
  (liii check)
  (liii string)
  (liii pi agent tools)
  (liii pi ai message)
  (liii pi ai tools result)
) ;import

(check-set-mode! 'report-failed)

;; 1. 执行普通工具：验证事件发射与结果消息构造
(let* ((evs '())
       (mock-emit
         (lambda (ev-type . args) (set! evs (cons (cons ev-type args) evs)))
       ) ;mock-emit
       (mock-exec (lambda (name args . opts) (pi-tool-result "hello" #f)))
       (cfg (list (cons 'execute-tool-call mock-exec)))
       (call '((id . "call_1") (name . "toolA") (arguments)))
       (msg (pi-execute-one-tool-call call mock-emit 10 cfg))
      ) ;
  (check-true (pi-tool-result-message? msg))
  (check (pi-tool-result-message-role msg) => "toolResult")
  (check (pi-tool-result-message-tool-call-id msg) => "call_1")
  (check (pi-tool-result-message-tool-name msg) => "toolA")
  (check (pi-text-block-text (car (pi-tool-result-message-content msg)))
    =>
    "hello"
  ) ;check
  (let ((types (map car (reverse evs))))
    (check-true (pair? (member 'tool_execution_start types)))
    (check-true (pair? (member 'tool_execution_end types)))
    (check-true (pair? (member 'message_start types)))
    (check-true (pair? (member 'message_end types)))
  ) ;let
  ;; tool_execution_end 事件携带真实执行耗时（数值）
  (let ((end-ev (assq 'tool_execution_end evs)))
    (check-true (number? (list-ref end-ev 5)))
  ) ;let
) ;let*

;; 2. 传递 opt-config 时正常执行
(let* ((mock-exec (lambda (name args . opts) (pi-tool-result "config-ok" #f)))
       (cfg (list (cons 'execute-tool-call mock-exec) (cons 'provider "google")))
       (call '((id . "call_2") (name . "toolA") (arguments)))
       (msg (pi-execute-one-tool-call call #f 10 cfg))
      ) ;
  (check-true (pi-tool-result-message? msg))
  (check (pi-text-block-text (car (pi-tool-result-message-content msg)))
    =>
    "config-ok"
  ) ;check
) ;let*

;; 3. 执行结果包含图片块时，toolResult 消息完整保留多模态图片块
(let* ((mock-exec
         (lambda (name args . opts)
           (pi-tool-result (list (pi-text-block "Read image file [image/png]")
                             (pi-image-block "aGVsbG8=" "image/png")
                           ) ;list
             #f
           ) ;pi-tool-result
         ) ;lambda
       ) ;mock-exec
       (cfg (list (cons 'execute-tool-call mock-exec)))
       (call '((id . "call_img") (name . "read") (arguments)))
       (msg (pi-execute-one-tool-call call #f 10 cfg))
      ) ;
  (check-true (pi-tool-result-message? msg))
  (let ((content (pi-tool-result-message-content msg)))
    (check (length content) => 2)
    (check-true (pi-text-block? (car content)))
    (check-true (pi-image-block? (cadr content)))
    (check (pi-image-block-data (cadr content)) => "aGVsbG8=")
    (check (pi-image-block-mime-type (cadr content)) => "image/png")
  ) ;let
) ;let*

(check-report)
