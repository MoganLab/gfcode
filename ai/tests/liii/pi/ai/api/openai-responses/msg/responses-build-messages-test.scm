;; responses-build-messages
;; responses-build-request-body
;; responses-build-tool-declarations
;; Responses API 请求体构建：input 扁平 item、工具声明扁平、系统提示置于 input[0]。

(import (liii check)
  (liii string)
  (liii json)
  (liii pi ai api openai-responses)
  (liii pi ai message)
  (liii pi ai tools definition)
) ;import

(check-set-mode! 'report-failed)

;; 系统提示作为 input[0] 的 system 消息（纳入可缓存前缀，而非顶层 instructions）
(let* ((msgs (list (pi-user-message "hi")))
       (input (responses-build-messages msgs "You are a bot"))
      ) ;
  (check (vector? input) => #t)
  (check (> (vector-length input) 1) => #t)
  (let ((first-item (vector-ref input 0)))
    (check (cdr (assoc "role" first-item)) => "system")
    (check (cdr (assoc "type" first-item)) => "message")
    (let* ((content (cdr (assoc "content" first-item))) (part (vector-ref content 0)))
      (check (cdr (assoc "type" part)) => "input_text")
      (check (cdr (assoc "text" part)) => "You are a bot")
    ) ;let*
  ) ;let
) ;let*

;; 空系统提示不插入 system item
(let* ((msgs (list (pi-user-message "hi")))
       (input (responses-build-messages msgs "   "))
      ) ;
  (check (vector? input) => #t)
  (check (vector-length input) => 1)
  (check (cdr (assoc "role" (vector-ref input 0))) => "user")
) ;let*

;; user 消息走 input_text
(let* ((msgs (list (pi-user-message "hello")))
       (input (responses-build-messages msgs #f))
      ) ;
  (check (vector-length input) => 1)
  (let* ((item (vector-ref input 0))
         (content (cdr (assoc "content" item)))
         (part (vector-ref content 0))
        ) ;
    (check (cdr (assoc "type" part)) => "input_text")
    (check (cdr (assoc "text" part)) => "hello")
  ) ;let*
) ;let*

;; assistant 文本 + 工具调用拆成 message + function_call 两条 item
(let* ((tc-block (pi-tool-call-block "call_1" "bash" '(("command" . "ls"))))
       (asst (pi-assistant-message (list (pi-text-block "run it") tc-block)))
       (msgs (list (pi-user-message "do it") asst))
       (input (responses-build-messages msgs #f))
      ) ;
  (check (>= (vector-length input) 3) => #t)
  ;; 第二条是 assistant output_text message
  (let* ((asst-item (vector-ref input 1)))
    (check (cdr (assoc "role" asst-item)) => "assistant")
  ) ;let*
  ;; 第三条是 function_call
  (let ((fc-item (vector-ref input 2)))
    (check (cdr (assoc "type" fc-item)) => "function_call")
    (check (cdr (assoc "call_id" fc-item)) => "call_1")
    (check (cdr (assoc "name" fc-item)) => "bash")
  ) ;let
) ;let*

;; tool result 转 function_call_output
(let* ((tr (pi-tool-result-message "call_1" "bash" (list (pi-text-block "done"))))
       (msgs (list (pi-user-message "x") tr))
       (input (responses-build-messages msgs #f))
      ) ;
  (let ((fco (vector-ref input 1)))
    (check (cdr (assoc "type" fco)) => "function_call_output")
    (check (cdr (assoc "call_id" fco)) => "call_1")
    (check (cdr (assoc "output" fco)) => "done")
  ) ;let
) ;let*

;; 工具声明：Responses 扁平结构（type=function，name 在顶层）
(let* ((def (pi-tool-definition "bash" "run command" '(("type" . "object"))))
       (decls (responses-build-tool-declarations (list def)))
      ) ;
  (check (length decls) => 1)
  (let ((d (car decls)))
    (check (cdr (assoc "type" d)) => "function")
    (check (cdr (assoc "name" d)) => "bash")
    (check (cdr (assoc "description" d)) => "run command")
  ) ;let
) ;let*

;; 请求体：model/input/store=false，stream 时带 stream=true 与 tools
(let* ((input (responses-build-messages (list (pi-user-message "hi")) #f))
       (decls
         (responses-build-tool-declarations
           (list (pi-tool-definition "bash" "run" '(("type" . "object"))))
         ) ;responses-build-tool-declarations
       ) ;decls
       (body (responses-build-request-body "gpt-6.2-astra" input #t decls 1024))
      ) ;
  (check (cdr (assoc "model" body)) => "gpt-6.2-astra")
  (check (vector? (cdr (assoc "input" body))) => #t)
  (check (cdr (assoc "store" body)) => #f)
  (check (cdr (assoc "stream" body)) => #t)
  (check (cdr (assoc "max_output_tokens" body)) => 1024)
  (check (vector? (cdr (assoc "tools" body))) => #t)
  ;; 无 instructions 字段（系统提示已在 input[0]）
  (check (assoc "instructions" body) => #f)
) ;let*

;; 非流式不带 stream 字段
(let* ((input (responses-build-messages (list (pi-user-message "hi")) #f))
       (body (responses-build-request-body "m" input #f '() 512))
      ) ;
  (check (assoc "stream" body) => #f)
) ;let*

(check-report)
