;; pi-request-provider / pi-request-provider-stream 对 openai-responses 的路由。
;; 用一个不可达端点确认 dispatch 走 openai-responses 分支：返回结构化错误消息，
;; 且 api 字段为 "openai-responses"（而非默认 Gemini 分支）。
;;
;; 语法
;; ----
;; (pi-request-provider provider config msgs sys-prompt tools timeout opt-retry)
;; (pi-request-provider-stream provider config msgs sys-prompt tools on-ev timeout)
;;
;; 参数
;; ----
;; provider : string
;; 供应商名称。
;; config : alist
;; 含 provider-api="openai-responses" 的请求配置。
;; msgs : list
;; 会话消息列表。
;; sys-prompt : string | #f
;; 系统提示词。
;; tools : list
;; 工具名列表。
;; on-ev : procedure | #f
;; 流式事件回调。
;; timeout : number
;; 超时秒数。
;; opt-retry : alist | #f
;; 重试覆盖配置。
;;
;; 返回值
;; ----
;; <pi-assistant-message>
;; 端点不可达时返回结构化错误消息，api 字段为 "openai-responses"。

(import (scheme base) (liii check) (liii pi ai message) (liii pi ai dispatch))

(check-set-mode! 'report-failed)

(define (config-for api)
  (list (cons 'provider "custom")
    (cons 'provider-api api)
    (cons 'model-id "gpt-6.2-astra")
    (cons 'model-meta
      (list (cons 'base-url "http://127.0.0.1:1") (cons 'max-tokens 32))
    ) ;cons
    (cons 'api-key "k")
    (cons 'proxy-url #f)
    (cons 'tools '())
    (cons 'settings '((retry (enabled . #f))))
  ) ;list
) ;define

;; 非流式路由到 openai-responses
(let ((resp (pi-request-provider "custom"
              (config-for "openai-responses")
              (list (pi-user-message "ping"))
              #f
              '()
              1
              '((enabled . #f))
            ) ;pi-request-provider
      ) ;resp
     ) ;
  (check (pi-assistant-message? resp) => #t)
  (check (pi-assistant-message-stop-reason resp) => "error")
  ;; api 字段标识走了 openai-responses 分支
  (check (pi-assistant-message-api resp) => "openai-responses")
) ;let

;; 流式路由到 openai-responses
(let ((resp (pi-request-provider-stream "custom"
              (config-for "openai-responses")
              (list (pi-user-message "ping"))
              #f
              '()
              #f
              1
            ) ;pi-request-provider-stream
      ) ;resp
     ) ;
  (check (pi-assistant-message? resp) => #t)
  (check (pi-assistant-message-stop-reason resp) => "error")
  (check (pi-assistant-message-api resp) => "openai-responses")
) ;let

(check-report)
