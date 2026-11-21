;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OpenAI Responses API 核心解析：
;; - responses-map-stop-reason：把 Responses 状态映射为内部 stop-reason
;; - responses-map-usage：把 Responses usage 映射为内部 usage alist
;; - responses-parse-response：非流式响应解析为 pi-assistant-message
;; - responses-is-retriable-error?：错误可重试判定（与 openai-completions 一致）
(define-library (liii pi ai api openai-responses core)
  (import (scheme base)
    (liii string)
    (liii json)
    (liii error)
    (liii pi ai message)
    (liii pi ai limits)
  ) ;import
  (export responses-map-stop-reason responses-map-usage responses-parse-response
    responses-is-retriable-error?
  ) ;export
  (begin

    ;; 兼容字符串/符号键的 alist 取值
    (define (%val key obj default-val)
      (if (not (pair? obj))
        default-val
        (let ((p
                (or (assoc key obj)
                  (assoc (if (symbol? key) (symbol->string key) (string->symbol key)) obj)
                ) ;or
              ) ;p
             ) ;
          (if (pair? p) (cdr p) default-val)
        ) ;let
      ) ;if
    ) ;define

    (define (%num-val key obj default-val)
      (let ((v (%val key obj default-val)))
        (if (number? v) v default-val)
      ) ;let
    ) ;define

    ;; Responses 响应状态 -> 内部 stop-reason
    ;; completed/incomplete/failed/cancelled 等映射；function_call 视为 toolUse。
    (define (responses-map-stop-reason status)
      (let ((s (if (symbol? status) (symbol->string status) status)))
        (cond ((equal? s "completed") "stop")
              ((equal? s "incomplete") "length")
              ((equal? s "cancelled") "stop")
              ((equal? s "failed") "error")
              ((equal? s "toolUse") "toolUse")
              ((string? s) "error")
              (else "error")
        ) ;cond
      ) ;let
    ) ;define

    ;; Responses usage -> 内部 usage alist（与 openai-completions 字段对齐）
    ;; input_tokens / output_tokens 顶层；cached/reasoning 取自 *_details。
    (define (responses-map-usage usage-meta)
      (let* ((prompt-tokens (%num-val "input_tokens" usage-meta 0))
             (completion-tokens (%num-val "output_tokens" usage-meta 0))
             (in-details (%val "input_tokens_details" usage-meta '()))
             (out-details (%val "output_tokens_details" usage-meta '()))
             (cached (%num-val "cached_tokens" in-details 0))
             (reasoning-tok (%num-val "reasoning_tokens" out-details 0))
             (tot-tok (+ prompt-tokens completion-tokens))
            ) ;
        (list (cons 'input prompt-tokens)
          (cons 'output completion-tokens)
          (cons 'cacheRead cached)
          (cons 'cacheWrite 0)
          (cons 'reasoning reasoning-tok)
          (cons 'totalTokens tot-tok)
        ) ;list
      ) ;let*
    ) ;define

    ;; 从 output item 列表中提取 message/reasoning/function_call 的内容块。
    ;; message：content 内的 output_text 文本；function_call：工具调用块。
    (define (%extract-message-text msg-item)
      (let ((content (%val "content" msg-item #())))
        (cond ((string? content) (list (pi-text-block content)))
              ((vector? content)
               (let loop
                 ((i 0) (acc '()))
                 (if (>= i (vector-length content))
                   (reverse acc)
                   (let* ((part (vector-ref content i))
                          (ptype (%val "type" part "output_text"))
                          (text (%val "text" part #f))
                         ) ;
                     (loop (+ i 1)
                       (if (and (string? text)
                             (or (equal? ptype "output_text") (equal? ptype "reasoning_text"))
                           ) ;and
                         (cons (pi-text-block text) acc)
                         acc
                       ) ;if
                     ) ;loop
                   ) ;let*
                 ) ;if
               ) ;let
              ) ;
              ((pair? content)
               (let loop
                 ((rest content) (acc '()))
                 (if (null? rest)
                   (reverse acc)
                   (let* ((part (car rest))
                          (ptype (%val "type" part "output_text"))
                          (text (%val "text" part #f))
                         ) ;
                     (loop (cdr rest)
                       (if (and (string? text)
                             (or (equal? ptype "output_text") (equal? ptype "reasoning_text"))
                           ) ;and
                         (cons (pi-text-block text) acc)
                         acc
                       ) ;if
                     ) ;loop
                   ) ;let*
                 ) ;if
               ) ;let
              ) ;
              (else '())
        ) ;cond
      ) ;let
    ) ;define

    (define (%function-call->block fc-item)
      (let* ((raw-id (%val "id" fc-item ""))
             (id (if (string? raw-id) raw-id ""))
             (call-id (or (%val "call_id" fc-item #f) id))
             (name (%val "name" fc-item ""))
             (raw-args (%val "arguments" fc-item "{}"))
             (args
               (cond
                ((string? raw-args)
                 (catch #t (lambda () (string->json raw-args)) (lambda args '()))
                ) ;
                ((pair? raw-args) raw-args)
                (else '())
               ) ;cond
             ) ;args
            ) ;
        (pi-tool-call-block call-id name args)
      ) ;let*
    ) ;define

    ;; 从 output item 列表中按出现顺序提取内容块（文本 + 工具调用）。
    (define (%extract-blocks output)
      (let loop
        ((rest (if (vector? output) (vector->list output) output)) (acc '()))
        (if (null? rest)
          (reverse acc)
          (let* ((item (car rest)) (itype (%val "type" item "")))
            (cond
             ((equal? itype "message")
              (loop (cdr rest) (append (reverse (%extract-message-text item)) acc))
             ) ;
             ((equal? itype "function_call")
              (loop (cdr rest) (cons (%function-call->block item) acc))
             ) ;
             (else (loop (cdr rest) acc))
            ) ;cond
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define* (responses-parse-response json-data
               status-code
               (provider #f)
               (model-id #f)
               (api "openai-responses")
             ) ;responses-parse-response
      (if (not (json-object? json-data))
        (pi-assistant-message (list (pi-text-block ""))
          :stop-reason   "error"
          :usage         (responses-map-usage '())
          :error-message "Invalid JSON response from OpenAI Responses API"
          :provider      provider
          :model         model-id
          :api           api
        ) ;pi-assistant-message
        (let* ((err (%val "error" json-data #f))
               (usage (responses-map-usage (%val "usage" json-data '())))
              ) ;
          (if (pair? err)
            (pi-assistant-message (list (pi-text-block ""))
              :stop-reason   "error"
              :usage         usage
              :error-message (%val "message" err "OpenAI Responses API error")
              :provider      provider
              :model         model-id
              :api           api
            ) ;pi-assistant-message
            (let* ((status (%val "status" json-data "completed"))
                   (output (%val "output" json-data #()))
                   (blocks (%extract-blocks output))
                   (stop-reason (responses-map-stop-reason status))
                  ) ;
              (pi-assistant-message blocks
                :stop-reason   stop-reason
                :usage         usage
                :error-message (if (equal? stop-reason "error") status #f)
                :provider      provider
                :model         model-id
                :api           api
              ) ;pi-assistant-message
            ) ;let*
          ) ;if
        ) ;let*
      ) ;if
    ) ;define*

    ;; 与 openai-completions 一致：额度耗尽不可重试，其余瞬时错误可重试。
    (define* (responses-is-retriable-error? status-code response-body-str (provider #f))
      (if (pi-usage-limit-error? status-code response-body-str provider)
        #f
        (if (memv status-code '(0 408 409 429 500 502 503 504 529)) #t #f)
      ) ;if
    ) ;define*

  ) ;begin
) ;define-library
