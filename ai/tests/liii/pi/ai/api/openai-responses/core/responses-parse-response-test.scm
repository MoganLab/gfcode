;; responses-map-stop-reason
;; responses-map-usage
;; responses-parse-response
;; 把 OpenAI Responses API 响应映射为内部 assistant message。

(import (liii check) (liii pi ai api openai-responses) (liii pi ai message))

(check-set-mode! 'report-failed)

;; responses-map-stop-reason 映射
(check (responses-map-stop-reason "completed") => "stop")
(check (responses-map-stop-reason "incomplete") => "length")
(check (responses-map-stop-reason "cancelled") => "stop")
(check (responses-map-stop-reason "failed") => "error")
(check (responses-map-stop-reason "toolUse") => "toolUse")
(check (responses-map-stop-reason #f) => "error")

;; responses-map-usage 字段对齐
(let ((usage
        (responses-map-usage '(("input_tokens" . 12)
                               ("output_tokens" . 7)
                               ("input_tokens_details" ("cached_tokens" . 4))
                               ("output_tokens_details"
                                ("reasoning_tokens" . 3)))
        ) ;responses-map-usage
      ) ;usage
     ) ;
  (check (cdr (assoc 'input usage)) => 12)
  (check (cdr (assoc 'output usage)) => 7)
  (check (cdr (assoc 'cacheRead usage)) => 4)
  (check (cdr (assoc 'reasoning usage)) => 3)
  (check (cdr (assoc 'totalTokens usage)) => 19)
) ;let

;; 空 usage 不抛错
(let ((usage (responses-map-usage '())))
  (check (cdr (assoc 'input usage)) => 0)
  (check (cdr (assoc 'totalTokens usage)) => 0)
) ;let

;; 非流式文本响应解析
(let* ((json-data '(("id" . "resp_1")
                    ("status" . "completed")
                    ("output"
                     . #((("type" . "message")
                          ("role" . "assistant")
                          ("content"
                           . #((("type" . "output_text") ("text" . "PONG")))))
                       ) ;#
                    )
                    ("usage"
                     ("input_tokens" . 10)
                     ("output_tokens" . 5)
                     ("total_tokens" . 15)))
       ) ;json-data
       (resp (responses-parse-response json-data 200))
      ) ;
  (check (pi-assistant-message? resp) => #t)
  (check (pi-assistant-message-stop-reason resp) => "stop")
  (check (pi-assistant-message-api resp) => "openai-responses")
  (let ((content (pi-assistant-message-content resp)))
    (check (length content) => 1)
    (check (pi-text-block-text (car content)) => "PONG")
  ) ;let
) ;let*

;; 工具调用响应解析
(let* ((json-data '(("id" . "resp_2")
                    ("status" . "completed")
                    ("output"
                     . #((("type" . "function_call")
                          ("id" . "fc_1")
                          ("call_id" . "call_1")
                          ("name" . "bash")
                          ("arguments" . "{\"command\":\"echo hi\"}"))
                       ) ;#
                    )
                    ("usage" ("input_tokens" . 8) ("output_tokens" . 2)))
       ) ;json-data
       (resp (responses-parse-response json-data 200))
      ) ;
  (check (pi-assistant-message? resp) => #t)
  (check (pi-assistant-message-stop-reason resp) => "stop")
  (let ((content (pi-assistant-message-content resp)))
    (check (length content) => 1)
    (check (pi-tool-call-block? (car content)) => #t)
    (check (pi-tool-call-block-id (car content)) => "call_1")
    (check (pi-tool-call-block-name (car content)) => "bash")
  ) ;let
) ;let*

;; 错误响应
(let* ((json-data '(("error"
                     ("message" . "bad model")
                     ("type" . "invalid_request_error"))
                    ("usage" ("input_tokens" . 0) ("output_tokens" . 0)))
       ) ;json-data
       (resp (responses-parse-response json-data 400))
      ) ;
  (check (pi-assistant-message-stop-reason resp) => "error")
  (check (pi-assistant-message-error-message resp) => "bad model")
) ;let*

;; 非 JSON 响应
(let ((resp (responses-parse-response #f 200)))
  (check (pi-assistant-message-stop-reason resp) => "error")
  (check-true (string? (pi-assistant-message-error-message resp)))
) ;let

(check-report)
