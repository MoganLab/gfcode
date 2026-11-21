;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OpenAI Responses API 请求体构建：
;; - input 是扁平 item 列表：message/function_call/function_call_output
;; - 工具声明扁平结构（name/description/parameters 在顶层，非 function 包装）
;; - content part 类型按角色区分：user -> input_text，assistant -> output_text
;;
;; 缓存优化（关键）：OpenAI 对 GPT-5/6 模型仅按序列化后的 input 数组 + tools 计算
;; 缓存键，顶层 instructions 不计入缓存前缀（GPT-6.2+ 还会把 instructions 排在
;; input 之后，命中边界之外）。若把系统提示放进 instructions，每次请求都按未缓存
;; 输入价计费、缓存命中率趋近 0（见 OmniRoute PR #1346 的 0% 命中复现）。
;; 因此系统提示一律以 role="system" 的消息置于 input[0]，纳入可缓存前缀，
;; 与会话历史、tools 一起构成稳定前缀；每轮只追加新 user 消息，仅尾部变化。
(define-library (liii pi ai api openai-responses msg)
  (import (scheme base)
    (liii string)
    (liii json)
    (liii list)
    (liii pi ai message)
    (liii pi ai tools definition)
    (liii pi ai api openai-responses thinking)
  ) ;import
  (export responses-build-tool-declarations responses-build-messages
    responses-build-request-body responses-resolve-prompt-cache-key
    responses-clamp-prompt-cache-key
  ) ;export
  (begin

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

    (define (%msg-role msg)
      (if (pi-message? msg) (pi-message-role msg) (%val 'role msg ""))
    ) ;define

    ;; 工具声明：Responses 扁平结构（type="function"，name/description/parameters 在顶层）
    (define (responses-build-tool-declarations tool-defs)
      (map
        (lambda (def)
          (let ((params
                  (if (pi-tool-definition? def)
                    (pi-tool-definition-parameters def)
                    (or (%val 'parameters def #f)
                      (%val 'parametersJsonSchema def #f)
                      '(("type" . "object"))
                    ) ;or
                  ) ;if
                ) ;params
                (name (if (pi-tool-definition? def) (pi-tool-definition-name def) (%val 'name def ""))
                ) ;name
                (desc (if (pi-tool-definition? def)
                        (pi-tool-definition-description def)
                        (%val 'description def "")
                      ) ;if
                ) ;desc
               ) ;
            (list (cons "type" "function")
              (cons "name" name)
              (cons "description" desc)
              (cons "parameters" params)
            ) ;list
          ) ;let
        ) ;lambda
        tool-defs
      ) ;map
    ) ;define

    (define (%block->text blk)
      (cond ((string? blk) blk)
            ((pi-text-block? blk) (pi-text-block-text blk))
            ((pair? blk) (%val 'text blk ""))
            (else "")
      ) ;cond
    ) ;define

    (define (%msg-text-content content)
      (cond ((string? content) content)
            ((vector? content) (%msg-text-content (vector->list content)))
            ((pair? content) (apply string-append (map %block->text content)))
            (else "")
      ) ;cond
    ) ;define

    (define (%assistant-text-block? blk)
      (or (pi-text-block? blk) (equal? (%val 'type blk "") "text"))
    ) ;define

    (define (%is-image-block? b)
      (or (pi-image-block? b) (equal? (%val 'type b "") "image"))
    ) ;define

    ;; 把内部 image block 转为 Responses input_image content part
    (define (%image-block->responses-item b)
      (let ((mime (if (pi-image-block? b)
                    (pi-image-block-mime-type b)
                    (%val 'mimeType b (%val 'media_type b "image/png"))
                  ) ;if
            ) ;mime
            (data (if (pi-image-block? b) (pi-image-block-data b) (%val 'data b "")))
           ) ;
        (list (cons "type" "input_image")
          (cons "image_url" (string-append "data:" mime ";base64," data))
        ) ;list
      ) ;let
    ) ;define

    (define (%model-supports-images? model)
      (if (not (pair? model))
        #t
        (let ((input
                (or (and (assoc "input" model) (cdr (assoc "input" model)))
                  (and (assoc 'input model) (cdr (assoc 'input model)))
                  #f
                ) ;or
              ) ;input
             ) ;
          (cond ((vector? input) (member "image" (vector->list input)))
                ((pair? input) (member "image" input))
                (else #t)
          ) ;cond
        ) ;let
      ) ;if
    ) ;define

    (define (%normalize-json-keys-to-strings data)
      (cond
       ((pair? data)
        (if (pair? (car data))
          (map
            (lambda (p)
              (let* ((key (car p))
                     (str-key (if (symbol? key) (symbol->string key) key))
                     (val (cdr p))
                    ) ;
                (cons str-key (%normalize-json-keys-to-strings val))
              ) ;let*
            ) ;lambda
            data
          ) ;map
          (let* ((key (car data)) (str-key (if (symbol? key) (symbol->string key) key)))
            (cons str-key (%normalize-json-keys-to-strings (cdr data)))
          ) ;let*
        ) ;if
       ) ;
       ((vector? data)
        (list->vector (map %normalize-json-keys-to-strings (vector->list data)))
       ) ;
       (else data)
      ) ;cond
    ) ;define

    (define (%ensure-strict-json-string obj)
      (cond
       ((string? obj)
        (let ((parsed (catch #t (lambda () (string->json obj)) (lambda _ #f))))
          (if (and parsed (not (eof-object? parsed)))
            (json->string (%normalize-json-keys-to-strings parsed))
            obj
          ) ;if
        ) ;let
       ) ;
       ((pair? obj) (json->string (%normalize-json-keys-to-strings obj)))
       (else (json->string obj))
      ) ;cond
    ) ;define

    ;; 把 assistant 消息的 tool-call 块转为 function_call input item
    (define (%assistant-block->function-call blk)
      (and (or (pi-tool-call-block? blk) (equal? (%val 'type blk "") "toolCall"))
        (let* ((id (if (pi-tool-call-block? blk) (pi-tool-call-block-id blk) (%val 'id blk ""))
               ) ;id
               (name (if (pi-tool-call-block? blk) (pi-tool-call-block-name blk) (%val 'name blk ""))
               ) ;name
               (raw-args (if (pi-tool-call-block? blk)
                           (pi-tool-call-block-arguments blk)
                           (%val 'arguments blk '())
                         ) ;if
               ) ;raw-args
               (args-str (%ensure-strict-json-string raw-args))
              ) ;
          (list (cons "type" "function_call")
            (cons "call_id" id)
            (cons "name" name)
            (cons "arguments" args-str)
          ) ;list
        ) ;let*
      ) ;and
    ) ;define

    ;; assistant 消息：拆成一条 message（output_text）+ 若干 function_call item
    ;; 空 assistant 消息（ESC abort 残留）跳过，避免被 API 拒绝。
    (define (%convert-assistant-msg msg)
      (let* ((raw-c (if (pi-assistant-message? msg)
                      (pi-assistant-message-content msg)
                      (%val 'content msg '())
                    ) ;if
             ) ;raw-c
             (c-list (cond ((vector? raw-c) (vector->list raw-c))
                           ((pair? raw-c) raw-c)
                           (else '())
                     ) ;cond
             ) ;c-list
             (text-acc (%msg-text-content (filter %assistant-text-block? c-list)))
             (fc-acc (filter (lambda (fc) fc) (map %assistant-block->function-call c-list)))
            ) ;
        (cond ((and (null? fc-acc) (string-null? text-acc)) '())
              ((pair? fc-acc)
               (append
                 (if (string-null? text-acc)
                   '()
                   (list
                     (list (cons "type" "message")
                       (cons "role" "assistant")
                       (cons "content"
                         (list->vector (list (list (cons "type" "output_text") (cons "text" text-acc))))
                       ) ;cons
                     ) ;list
                   ) ;list
                 ) ;if
                 fc-acc
               ) ;append
              ) ;
              (else
                (list
                  (list (cons "type" "message")
                    (cons "role" "assistant")
                    (cons "content"
                      (list->vector (list (list (cons "type" "output_text") (cons "text" text-acc))))
                    ) ;cons
                  ) ;list
                ) ;list
              ) ;else
        ) ;cond
      ) ;let*
    ) ;define

    ;; user 消息：文本走 input_text，图片走 input_image
    (define (%convert-user-msg msg opt-model)
      (let* ((raw-c (if (pi-user-message? msg)
                      (pi-user-message-content msg)
                      (%val 'content msg '())
                    ) ;if
             ) ;raw-c
             (c-list (cond ((string? raw-c) (list raw-c))
                           ((vector? raw-c) (vector->list raw-c))
                           ((pair? raw-c) raw-c)
                           (else '())
                     ) ;cond
             ) ;c-list
             (text-parts
               (filter
                 (lambda (b)
                   (or (string? b)
                     (pi-text-block? b)
                     (and (pair? b) (equal? (%val 'type b "") "text"))
                   ) ;or
                 ) ;lambda
                 c-list
               ) ;filter
             ) ;text-parts
             (text-acc (%msg-text-content text-parts))
             (img-blks (filter %is-image-block? c-list))
            ) ;
        (cond
         ((and (pair? img-blks) (or (not opt-model) (%model-supports-images? opt-model)))
          (let ((parts
                  (append
                    (if (string-null? text-acc)
                      '()
                      (list (list (cons "type" "input_text") (cons "text" text-acc)))
                    ) ;if
                    (map %image-block->responses-item img-blks)
                  ) ;append
                ) ;parts
               ) ;
            (list (cons "type" "message")
              (cons "role" "user")
              (cons "content" (list->vector parts))
            ) ;list
          ) ;let
         ) ;
         ((string-null? text-acc) #f)
         (else
           (list (cons "type" "message")
             (cons "role" "user")
             (cons "content"
               (list->vector (list (list (cons "type" "input_text") (cons "text" text-acc))))
             ) ;cons
           ) ;list
         ) ;else
        ) ;cond
      ) ;let*
    ) ;define

    ;; tool result 消息：转为 function_call_output item
    (define (%convert-tool-result-msg tmsg opt-model)
      (let* ((raw-c (if (pi-tool-result-message? tmsg)
                      (pi-tool-result-message-content tmsg)
                      (%val 'content tmsg '())
                    ) ;if
             ) ;raw-c
             (c-list
               (cond ((vector? raw-c) (vector->list raw-c))
                     ((pair? raw-c) raw-c)
                     ((string? raw-c) (list (pi-text-block raw-c)))
                     (else '())
               ) ;cond
             ) ;c-list
             (call-id (if (pi-tool-result-message? tmsg)
                        (pi-tool-result-message-tool-call-id tmsg)
                        (%val 'toolCallId tmsg "")
                      ) ;if
             ) ;call-id
             (text-blks
               (filter
                 (lambda (b) (or (pi-text-block? b) (equal? (%val 'type b "") "text")))
                 c-list
               ) ;filter
             ) ;text-blks
             (img-blks (filter %is-image-block? c-list))
             (text-res (%msg-text-content text-blks))
             (eff-text
               (cond
                ((not (string-null? (string-trim-both text-res))) text-res)
                ((pair? img-blks) "(see attached image)")
                (else "")
               ) ;cond
             ) ;eff-text
            ) ;
        (list (cons "type" "function_call_output")
          (cons "call_id" call-id)
          (cons "output" eff-text)
        ) ;list
      ) ;let*
    ) ;define

    ;; 把系统提示构造成 input[0] 的 system 消息（纳入可缓存前缀）。
    ;; 空系统提示不插入，保持 input 仅含会话内容。
    (define (%system-message-item sys-inst)
      (if
        (and (string? sys-inst) (not (string-null? (string-trim-both sys-inst))))
        (list (cons "type" "message")
          (cons "role" "system")
          (cons "content"
            (list->vector (list (list (cons "type" "input_text") (cons "text" sys-inst))))
          ) ;cons
        ) ;list
        #f
      ) ;if
    ) ;define

    ;; 把内部会话消息列表转为 Responses input item 列表（vector）。
    ;; 系统提示作为 input[0] 的 system 消息，保证其进入可缓存前缀。
    ;; acc 以 cons 逆序累积，末尾 reverse 后再拼接 sys-item 到最前。
    (define* (responses-build-messages messages system-instruction (opt-model #f))
      (let* ((sys-item (%system-message-item system-instruction))
             (rev
               (let loop
                 ((rest messages) (acc '()))
                 (if (null? rest)
                   acc
                   (let* ((msg (car rest)) (role (%msg-role msg)))
                     (cond
                      ((equal? role "toolResult")
                       (loop (cdr rest) (cons (%convert-tool-result-msg msg opt-model) acc))
                      ) ;
                      ((equal? role "user")
                       (let ((converted (%convert-user-msg msg opt-model)))
                         (loop (cdr rest) (if converted (cons converted acc) acc))
                       ) ;let
                      ) ;
                      ((equal? role "assistant")
                       ;; items 正向顺序 [message, function_call...]；acc 逆序，
                       ;; 逐项反序 cons 使最终 reverse 后保持正向。
                       (let ((items (%convert-assistant-msg msg)))
                         (loop (cdr rest) (append (reverse items) acc))
                       ) ;let
                      ) ;
                      (else (loop (cdr rest) acc))
                     ) ;cond
                   ) ;let*
                 ) ;if
               ) ;let
             ) ;rev
             (items (reverse rev))
            ) ;
        (list->vector (if sys-item (cons sys-item items) items))
      ) ;let*
    ) ;define*

    ;; prompt_cache_key 最大长度（对齐上游 Responses 文档约束）
    (define %prompt-cache-key-max-length 64)

    (define (responses-clamp-prompt-cache-key key)
      (if (and (string? key) (> (string-length key) %prompt-cache-key-max-length))
        (substring key 0 %prompt-cache-key-max-length)
        key
      ) ;if
    ) ;define

    ;; prompt_cache_key 是把同一会话的请求路由到同一缓存实例的提示（非保证）。
    ;; 仅对 OpenAI 官方端点注入：第三方兼容端点对未知字段可能报错，与
    ;; openai-completions 保持一致的保守策略。缓存命中主要靠 input 前缀稳定，
    ;; 不依赖此字段。
    (define (responses-resolve-prompt-cache-key base-url session-id)
      (if (and (string? base-url)
            (string-contains? base-url "api.openai.com")
            (string? session-id)
            (> (string-length session-id) 0)
          ) ;and
        (responses-clamp-prompt-cache-key session-id)
        #f
      ) ;if
    ) ;define

    (define* (responses-build-request-body model-id
               messages
               stream?
               tool-decls
               max-tokens
               (prompt-cache-key #f)
               (thinking-level #f)
               (model-entry #f)
             ) ;responses-build-request-body
      (let* ((thinking-pairs (responses-thinking-request-params model-entry thinking-level))
             (pairs
               (append thinking-pairs
                 (list (and stream? (cons "stream" #t))
                   (and (integer? max-tokens)
                     (> max-tokens 0)
                     (cons "max_output_tokens" max-tokens)
                   ) ;and
                   (and (pair? tool-decls)
                     (> (length tool-decls) 0)
                     (cons "tools" (list->vector tool-decls))
                   ) ;and
                   (and (string? prompt-cache-key)
                     (> (string-length prompt-cache-key) 0)
                     (cons "prompt_cache_key" prompt-cache-key)
                   ) ;and
                 ) ;list
               ) ;append
             ) ;pairs
             (base (list (cons "model" model-id) (cons "input" messages)))
            ) ;
        ;; 无状态使用：每次请求带完整 input，不依赖服务端存储
        (let loop
          ((rest pairs) (acc (append base (list (cons "store" #f)))))
          (cond ((null? rest) acc)
                ((car rest) (loop (cdr rest) (append acc (list (car rest)))))
                (else (loop (cdr rest) acc))
          ) ;cond
        ) ;let
      ) ;let*
    ) ;define*

  ) ;begin
) ;define-library
