;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OpenAI Responses API 流式事件解析：
;; Responses 流用带 event: 名称的 SSE 帧（response.output_text.delta 等），
;; 与 openai-completions 的 data: chunk 帧不同。本模块把每个事件载荷映射为
;; 内部 blocks 与 on-event 事件（text_start/text_delta/thinking_*/toolcall_*），
;; 事件类型与 openai-completions stream-parse 保持一致，供 agent 层复用渲染。
(define-library (liii pi ai api openai-responses stream-parse)
  (import (scheme base)
    (liii base)
    (liii string)
    (liii json)
    (liii sse)
    (liii pi ai message)
    (liii pi ai api openai-responses core)
    (liii pi ai api openai-responses stream-state)
  ) ;import
  (export append-responses-stream-text process-responses-tool-call-delta
    finish-responses-stream process-responses-chunk
    make-responses-stream-decoder extract-responses-stream-error-message
    %responses-event-data-key
  ) ;export
  (begin

    ;; 流式工具调用增量状态：按 output_index 累积
    (define*-record-type <responses-tool-state>
      (%make-responses-tool-state (id "") (name "") (args "") (emitted #f))
      %responses-tool-state?
      (id %responses-tool-state-id)
      (name %responses-tool-state-name)
      (args %responses-tool-state-args)
      (emitted %responses-tool-state-emitted)
    ) ;define*-record-type

    (define (extract-responses-stream-error-message body)
      (catch #t
        (lambda ()
          (let ((json-data (string->json body)))
            (and (json-object? json-data)
              (let ((err (json-ref json-data "error")))
                (cond ((json-object? err) (json-ref-string err "message" #f))
                      ((string? err) err)
                      (else #f)
                ) ;cond
              ) ;let
            ) ;and
          ) ;let
        ) ;lambda
        (lambda args #f)
      ) ;catch
    ) ;define

    (define (%thinking-block-index blocks)
      (let loop
        ((i 0) (rest blocks))
        (cond ((null? rest) #f)
              ((pi-thinking-block? (car rest)) i)
              (else (loop (+ i 1) (cdr rest)))
        ) ;cond
      ) ;let
    ) ;define

    (define (%replace-list-index lst idx val)
      (let loop
        ((i 0) (rest lst) (acc '()))
        (cond ((null? rest) (reverse acc))
              ((= i idx) (append (reverse acc) (cons val (cdr rest))))
              (else (loop (+ i 1) (cdr rest) (cons (car rest) acc)))
        ) ;cond
      ) ;let
    ) ;define

    (define (append-responses-stream-reasoning stream-state reasoning on-event)
      (when (and (string? reasoning) (not (string-null? reasoning)))
        (let* ((blocks (responses-stream-state-blocks stream-state))
               (idx (%thinking-block-index blocks))
               (last-reasoning (responses-stream-state-last-reasoning stream-state))
               (new-reasoning (if last-reasoning (string-append last-reasoning reasoning) reasoning)
               ) ;new-reasoning
               (usage (responses-stream-state-usage stream-state))
              ) ;
          (responses-stream-state-last-reasoning-set! stream-state new-reasoning)
          (if idx
            (let* ((blk (list-ref blocks idx))
                   (new-blk (pi-thinking-block new-reasoning (pi-thinking-block-thinking-signature blk))
                   ) ;new-blk
                  ) ;
              (responses-stream-state-blocks-set! stream-state
                (%replace-list-index blocks idx new-blk)
              ) ;responses-stream-state-blocks-set!
              (when (procedure? on-event)
                (on-event (list (cons 'type "thinking_delta")
                            (cons 'contentIndex idx)
                            (cons 'delta reasoning)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
              ) ;when
            ) ;let*
            (let ((cur-idx (length blocks)))
              (responses-stream-state-blocks-set! stream-state
                (append blocks (list (pi-thinking-block new-reasoning "reasoning_text")))
              ) ;responses-stream-state-blocks-set!
              (when (procedure? on-event)
                (on-event (list (cons 'type "thinking_start")
                            (cons 'contentIndex cur-idx)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
                (on-event (list (cons 'type "thinking_delta")
                            (cons 'contentIndex cur-idx)
                            (cons 'delta reasoning)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
              ) ;when
            ) ;let
          ) ;if
        ) ;let*
      ) ;when
    ) ;define

    (define (append-responses-stream-text stream-state text on-event)
      (when (and (string? text) (not (string-null? text)))
        (let* ((blocks (responses-stream-state-blocks stream-state))
               (last-text (responses-stream-state-last-text stream-state))
               (usage (responses-stream-state-usage stream-state))
              ) ;
          (if (not (string? last-text))
            (let ((cur-idx (length blocks)) (think-idx (%thinking-block-index blocks)))
              ;; 正文开始前关闭思考卡片，避免思考与正文卡片粘在一起
              (when (and think-idx (procedure? on-event))
                (on-event (list (cons 'type "thinking_end")
                            (cons 'contentIndex think-idx)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
              ) ;when
              (responses-stream-state-blocks-set! stream-state
                (append blocks (list (pi-text-block text)))
              ) ;responses-stream-state-blocks-set!
              (responses-stream-state-last-text-set! stream-state text)
              (when (procedure? on-event)
                (on-event (list (cons 'type "text_start")
                            (cons 'contentIndex cur-idx)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
                (on-event (list (cons 'type "text_delta")
                            (cons 'contentIndex cur-idx)
                            (cons 'delta text)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
              ) ;when
            ) ;let
            (let* ((cur-idx (max 0 (- (length blocks) 1)))
                   (new-text (string-append last-text text))
                   (upd-blocks
                     (let loop
                       ((lst blocks) (acc '()))
                       (if (null? (cdr lst))
                         (append (reverse acc) (list (pi-text-block new-text)))
                         (loop (cdr lst) (cons (car lst) acc))
                       ) ;if
                     ) ;let
                   ) ;upd-blocks
                  ) ;
              (responses-stream-state-blocks-set! stream-state upd-blocks)
              (responses-stream-state-last-text-set! stream-state new-text)
              (when (procedure? on-event)
                (on-event (list (cons 'type "text_delta")
                            (cons 'contentIndex cur-idx)
                            (cons 'delta text)
                            (cons 'usage usage)
                          ) ;list
                ) ;on-event
              ) ;when
            ) ;let*
          ) ;if
        ) ;let*
      ) ;when
    ) ;define

    ;; 处理 function_call 增量：按 output_index 累积 name/arguments
    (define (process-responses-tool-call-delta ev stream-state on-event)
      (let* ((idx (if (json-object? ev) (json-ref-integer ev "output_index" 0) 0))
             (item-id (if (json-object? ev) (json-ref-string ev "item_id" #f) #f))
             (name (if (json-object? ev) (json-ref-string ev "name" #f) #f))
             (args-delta (if (json-object? ev) (json-ref-string ev "delta" #f) #f))
             (args-delta (if (string? args-delta) args-delta ""))
             (tools-alist (responses-stream-state-tools stream-state))
             (entry (assoc idx tools-alist))
             (curr-item (if entry (cdr entry) (%make-responses-tool-state "" "" "" #f)))
             (curr-id
               (if (and (string? item-id) (not (string-null? item-id)))
                 item-id
                 (%responses-tool-state-id curr-item)
               ) ;if
             ) ;curr-id
             (curr-name
               (if (and (string? name) (not (string-null? name)))
                 name
                 (%responses-tool-state-name curr-item)
               ) ;if
             ) ;curr-name
             (curr-args (string-append (%responses-tool-state-args curr-item) args-delta))
             (was-emitted? (%responses-tool-state-emitted curr-item))
             (usage (responses-stream-state-usage stream-state))
             (blocks (responses-stream-state-blocks stream-state))
             (cur-idx (+ (length blocks) (length tools-alist)))
             (should-emit-start? (and (not was-emitted?) (not (string-null? curr-name))))
             (upd-item (%make-responses-tool-state curr-id
                         curr-name
                         curr-args
                         (or was-emitted? should-emit-start?)
                       ) ;%make-responses-tool-state
             ) ;upd-item
             (new-tools-alist
               (if entry
                 (map
                   (lambda (p) (if (equal? (car p) idx) (cons idx upd-item) p))
                   tools-alist
                 ) ;map
                 (append tools-alist (list (cons idx upd-item)))
               ) ;if
             ) ;new-tools-alist
            ) ;
        (responses-stream-state-tools-set! stream-state new-tools-alist)
        (when (procedure? on-event)
          (when should-emit-start?
            (on-event (list (cons 'type "toolcall_start")
                        (cons 'contentIndex cur-idx)
                        (cons 'id curr-id)
                        (cons 'toolName curr-name)
                        (cons 'usage usage)
                      ) ;list
            ) ;on-event
          ) ;when
          (when (and (string? args-delta) (not (string-null? args-delta)))
            (on-event (list (cons 'type "toolcall_delta")
                        (cons 'contentIndex cur-idx)
                        (cons 'delta args-delta)
                        (cons 'usage usage)
                      ) ;list
            ) ;on-event
          ) ;when
        ) ;when
      ) ;let*
    ) ;define

    ;; 流结束：把累积的工具调用固化进 blocks 并派发 toolcall_end
    (define (finish-responses-stream stream-state on-event)
      (let ((tools-alist (responses-stream-state-tools stream-state))
            (blocks (responses-stream-state-blocks stream-state))
            (usage (responses-stream-state-usage stream-state))
           ) ;
        (let ((think-idx (%thinking-block-index blocks)))
          (when (and think-idx (procedure? on-event))
            (on-event (list (cons 'type "thinking_end")
                        (cons 'contentIndex think-idx)
                        (cons 'usage usage)
                      ) ;list
            ) ;on-event
          ) ;when
        ) ;let
        (when (pair? tools-alist)
          (for-each
            (lambda (p)
              (let* ((item (cdr p))
                     (id (%responses-tool-state-id item))
                     (name (%responses-tool-state-name item))
                     (args-str (%responses-tool-state-args item))
                     (args-json
                       (catch #t
                         (lambda () (if (string-null? args-str) '() (string->json args-str)))
                         (lambda args '())
                       ) ;catch
                     ) ;args-json
                     (tc-blk (pi-tool-call-block id name args-json))
                     (cur-idx (length (responses-stream-state-blocks stream-state)))
                    ) ;
                (responses-stream-state-blocks-set! stream-state
                  (append (responses-stream-state-blocks stream-state) (list tc-blk))
                ) ;responses-stream-state-blocks-set!
                (when (procedure? on-event)
                  (on-event (list (cons 'type "toolcall_end")
                              (cons 'contentIndex cur-idx)
                              (cons 'id id)
                              (cons 'toolName name)
                              (cons 'usage usage)
                            ) ;list
                  ) ;on-event
                ) ;when
              ) ;let*
            ) ;lambda
            tools-alist
          ) ;for-each
          (responses-stream-state-stop-reason-set! stream-state "toolUse")
          (responses-stream-state-tools-set! stream-state '())
        ) ;when
      ) ;let
    ) ;define

    ;; 把单个事件 JSON 按 type 分派到文本/思考/工具调用增量
    (define (process-responses-chunk json-obj stream-state on-event)
      (when (json-object? json-obj)
        (let ((ev-type (json-ref-string json-obj "type" #f))
              (top-usage (json-ref json-obj "usage"))
             ) ;
          ;; 终态事件带累积 usage 与最终 stop-reason
          (when (json-object? top-usage)
            (responses-stream-state-usage-set! stream-state (responses-map-usage top-usage))
          ) ;when
          (cond
            ;; 文本增量
            ((member ev-type '("response.output_text.delta"
                               "response.text.delta"))
             (append-responses-stream-text stream-state
               (json-ref-string json-obj "delta" "")
               on-event
             ) ;append-responses-stream-text
            ) ;
            ;; 推理文本增量（reasoning_text）
            ((member ev-type
               '("response.reasoning_text.delta"
                 "response.reasoning_summary_text.delta")
             ) ;member
             (append-responses-stream-reasoning stream-state
               (json-ref-string json-obj "delta" "")
               on-event
             ) ;append-responses-stream-reasoning
            ) ;
            ;; 工具调用参数增量
            ((member ev-type '("response.function_call_arguments.delta"))
             (process-responses-tool-call-delta json-obj stream-state on-event)
            ) ;
            ;; 工具调用创建（output_item.added 中带 name）
            ((member ev-type '("response.output_item.added"))
             (let ((item (json-ref json-obj "item")))
               (when (json-object? item)
                 (let ((itype (json-ref-string item "type" #f))
                       (name (json-ref-string item "name" #f))
                      ) ;
                   ;; function_call 在 added 时给出 name，需登记并派发 toolcall_start
                   (when (and (equal? itype "function_call") (string? name))
                     (let* ((idx (json-ref-integer json-obj "output_index" 0))
                            (item-id (json-ref-string item "id" #f))
                            (args-delta "")
                            (tools-alist (responses-stream-state-tools stream-state))
                            (entry (assoc idx tools-alist))
                            (curr (%make-responses-tool-state (or item-id "") name "" #f))
                            (new-tools
                              (if entry
                                (map
                                  (lambda (p) (if (equal? (car p) idx) (cons idx curr) p))
                                  tools-alist
                                ) ;map
                                (append tools-alist (list (cons idx curr)))
                              ) ;if
                            ) ;new-tools
                           ) ;
                       (responses-stream-state-tools-set! stream-state new-tools)
                     ) ;let*
                   ) ;when
                 ) ;let
               ) ;when
             ) ;let
            ) ;
            ;; 工具调用完成（output_item.done 中带完整 arguments）
            ((member ev-type
               '("response.output_item.done"
                 "response.function_call_arguments.done")
             ) ;member
             (let ((item (json-ref json-obj "item")))
               (let* ((has-item (json-object? item))
                      (itype (if has-item (json-ref-string item "type" #f) #f))
                      (idx (json-ref-integer json-obj "output_index" 0))
                      (final-name (if has-item (json-ref-string item "name" #f) #f))
                      (final-args (if has-item (json-ref-string item "arguments" "") ""))
                      (final-id (if has-item (json-ref-string item "call_id" #f) #f))
                     ) ;
                 (when (equal? itype "function_call")
                   (let* ((tools-alist (responses-stream-state-tools stream-state))
                          (entry (assoc idx tools-alist))
                          (curr (if entry (cdr entry) (%make-responses-tool-state "" "" "" #f)))
                          (curr-name
                            (if (and (string? final-name) (not (string-null? final-name)))
                              final-name
                              (%responses-tool-state-name curr)
                            ) ;if
                          ) ;curr-name
                          (curr-id
                            (if (and (string? final-id) (not (string-null? final-id)))
                              final-id
                              (%responses-tool-state-id curr)
                            ) ;if
                          ) ;curr-id
                          (curr-args
                            (if (and (string? final-args) (not (string-null? final-args)))
                              final-args
                              (%responses-tool-state-args curr)
                            ) ;if
                          ) ;curr-args
                          (was-emitted? (%responses-tool-state-emitted curr))
                          (usage (responses-stream-state-usage stream-state))
                          (blocks (responses-stream-state-blocks stream-state))
                          (cur-idx (+ (length blocks) (length tools-alist)))
                          (upd (%make-responses-tool-state curr-id curr-name curr-args (or was-emitted? #t))
                          ) ;upd
                          (new-tools
                            (if entry
                              (map
                                (lambda (p) (if (equal? (car p) idx) (cons idx upd) p))
                                tools-alist
                              ) ;map
                              (append tools-alist (list (cons idx upd)))
                            ) ;if
                          ) ;new-tools
                         ) ;
                     (responses-stream-state-tools-set! stream-state new-tools)
                     (when (and (procedure? on-event) (not was-emitted?))
                       (on-event (list (cons 'type "toolcall_start")
                                   (cons 'contentIndex cur-idx)
                                   (cons 'id curr-id)
                                   (cons 'toolName curr-name)
                                   (cons 'usage usage)
                                 ) ;list
                       ) ;on-event
                     ) ;when
                   ) ;let*
                 ) ;when
               ) ;let*
             ) ;let
            ) ;
            ;; 终态：completed/incomplete/failed -> 映射 stop-reason
            ((member ev-type '("response.completed"
                               "response.incomplete"
                               "response.failed"))
             (let ((response-obj (json-ref json-obj "response"))
                   (status (cond ((equal? ev-type "response.incomplete") "incomplete")
                                 ((equal? ev-type "response.failed") "failed")
                                 (else "completed")
                           ) ;cond
                   ) ;status
                  ) ;
               ;; 终态 response 对象内的 usage 是最终累计值
               (when (json-object? response-obj)
                 (let ((u (json-ref response-obj "usage")))
                   (when (json-object? u)
                     (responses-stream-state-usage-set! stream-state (responses-map-usage u))
                   ) ;when
                 ) ;let
               ) ;when
               (responses-stream-state-stop-reason-set! stream-state
                 (responses-map-stop-reason status)
               ) ;responses-stream-state-stop-reason-set!
             ) ;let
            ) ;
            ;; 错误事件
            ((member ev-type '("error"))
             (let ((err (json-ref json-obj "error"))
                   (msg (json-ref-string json-obj "message" #f))
                  ) ;
               (responses-stream-state-error-message-set! stream-state
                 (or (and (json-object? err) (json-ref-string err "message" #f)) msg)
               ) ;responses-stream-state-error-message-set!
             ) ;let
            ) ;
            (else #f)
          ) ;cond
        ) ;let
      ) ;when
    ) ;define

    ;; 暴露事件载荷中提取 data 字段用的键名常量（SSE 帧的 data 字段）
    (define %responses-event-data-key "data")

    ;; SSE 解码器：Responses 帧带 event: 名称，data: 为 JSON 载荷。
    ;; 终态事件（response.completed/incomplete/failed/error）后停止。
    (define (make-responses-stream-decoder stream-state on-event)
      (let ((terminated? #f))
        (make-sse-decoder
          (lambda (ev)
            (if terminated?
              #f
              (let ((data (sse-event-data ev)) (ev-name (sse-event-event ev)))
                (cond ((not (string? data)) #f)
                      ;; 空行或 [DONE] 哨兵（Responses 一般不发，但兼容）
                      ((string=? (string-trim data) "[DONE]")
                       (finish-responses-stream stream-state on-event)
                       (set! terminated? #t)
                       #f
                      ) ;
                      (else
                        (let ((json-obj (catch #t (lambda () (string->json data)) (lambda args #f))))
                          (if (json-object? json-obj)
                            (begin
                              (process-responses-chunk json-obj stream-state on-event)
                              (let ((ev-type (json-ref-string json-obj "type" #f)))
                                ;; 终态后收尾并停止
                                (cond ((member ev-type
                                         '("response.completed"
                                           "response.incomplete"
                                           "response.failed" "error")
                                       ) ;member
                                       (finish-responses-stream stream-state on-event)
                                       (set! terminated? #t)
                                      ) ;
                                      (else #f)
                                ) ;cond
                              ) ;let
                            ) ;begin
                            ;; 非终态的不可解析帧：丢弃但继续
                            #f
                          ) ;if
                        ) ;let
                      ) ;else
                ) ;cond
              ) ;let
            ) ;if
          ) ;lambda
        ) ;make-sse-decoder
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
