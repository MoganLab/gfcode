;; process-responses-chunk
;; make-responses-stream-decoder
;; finish-responses-stream
;; Responses 流式事件解析：把 SSE 事件载荷映射为内部 blocks 与 on-event 事件。

(import (liii check)
  (liii json)
  (liii pi ai api openai-responses)
  (liii pi ai api openai-responses stream-state)
  (liii pi ai api openai-responses stream-parse)
  (liii pi ai message)
) ;import

(check-set-mode! 'report-failed)

(define (make-state)
  (make-responses-stream-state '() #f '() "stop" #f '())
) ;define

;; 文本增量 -> text block 与 text_start/text_delta 事件
(let* ((state (make-state))
       (events '())
       (emit (lambda (ev) (set! events (cons ev events))))
       (chunk (string->json "{\"type\":\"response.output_text.delta\",\"delta\":\"Hel\",\"output_index\":0}"
              ) ;string->json
       ) ;chunk
      ) ;
  (process-responses-chunk chunk state emit)
  (process-responses-chunk (string->json "{\"type\":\"response.output_text.delta\",\"delta\":\"lo\"}")
    state
    emit
  ) ;process-responses-chunk
  (let ((blocks (responses-stream-state-blocks state)))
    (check (length blocks) => 1)
    (check (pi-text-block? (car blocks)) => #t)
    (check (pi-text-block-text (car blocks)) => "Hello")
  ) ;let
  (check (responses-stream-state-last-text state) => "Hello")
  ;; 事件顺序：text_start 在最早，最后是 text_delta
  (let ((types (map (lambda (e) (cdr (assoc 'type e))) (reverse events))))
    (check (car types) => "text_start")
    (check (list-ref types (- (length types) 1)) => "text_delta")
  ) ;let
) ;let*

;; 推理文本增量 -> thinking block 与 thinking 事件
(let* ((state (make-state))
       (events '())
       (emit (lambda (ev) (set! events (cons ev events))))
      ) ;
  (process-responses-chunk (string->json "{\"type\":\"response.reasoning_text.delta\",\"delta\":\"thinking...\"}"
                           ) ;string->json
    state
    emit
  ) ;process-responses-chunk
  (let ((blocks (responses-stream-state-blocks state)))
    (check (length blocks) => 1)
    (check (pi-thinking-block? (car blocks)) => #t)
    (check (pi-thinking-block-thinking (car blocks)) => "thinking...")
  ) ;let
) ;let*

;; 工具调用增量 -> function_call block 与 toolcall_* 事件
(let* ((state (make-state))
       (events '())
       (emit (lambda (ev) (set! events (cons ev events))))
      ) ;
  ;; output_item.added 带 name
  (process-responses-chunk (string->json "{\"type\":\"response.output_item.added\",\"output_index\":0,\"item\":{\"type\":\"function_call\",\"id\":\"fc_1\",\"name\":\"bash\"}}"
                           ) ;string->json
    state
    emit
  ) ;process-responses-chunk
  ;; 参数增量
  (process-responses-chunk (string->json "{\"type\":\"response.function_call_arguments.delta\",\"output_index\":0,\"item_id\":\"fc_1\",\"delta\":\"{\\\"command\\\":\\\"ls\\\"}\"}"
                           ) ;string->json
    state
    emit
  ) ;process-responses-chunk
  (finish-responses-stream state emit)
  (let ((blocks (responses-stream-state-blocks state)))
    (check (length blocks) => 1)
    (check (pi-tool-call-block? (car blocks)) => #t)
    (check (pi-tool-call-block-name (car blocks)) => "bash")
    (check
      (cdr (assoc "command" (pi-tool-call-block-arguments (car blocks))))
      =>
      "ls"
    ) ;check
  ) ;let
  (check (responses-stream-state-stop-reason state) => "toolUse")
  (let ((types (map (lambda (e) (cdr (assoc 'type e))) (reverse events))))
    (check-true (if (member "toolcall_start" types) #t #f))
    (check-true (if (member "toolcall_end" types) #t #f))
  ) ;let
) ;let*

;; response.completed 事件携带 usage 与 stop-reason
(let* ((state (make-state)) (emit (lambda (ev) #t)))
  (process-responses-chunk (string->json "{\"type\":\"response.completed\",\"response\":{\"status\":\"completed\",\"usage\":{\"input_tokens\":12,\"output_tokens\":5,\"input_tokens_details\":{\"cached_tokens\":8}}}}"
                           ) ;string->json
    state
    emit
  ) ;process-responses-chunk
  (check (responses-stream-state-stop-reason state) => "stop")
  (let ((usage (responses-stream-state-usage state)))
    (check (cdr (assoc 'input usage)) => 12)
    (check (cdr (assoc 'cacheRead usage)) => 8)
  ) ;let
) ;let*

;; 错误事件记录 error-message
(let* ((state (make-state)) (emit (lambda (ev) #t)))
  (process-responses-chunk (string->json "{\"type\":\"error\",\"error\":{\"message\":\"bad key\",\"type\":\"auth\"}}"
                           ) ;string->json
    state
    emit
  ) ;process-responses-chunk
  (check (responses-stream-state-error-message state) => "bad key")
) ;let*

;; SSE 解码器：多帧 + 终态
(let* ((state (make-state))
       (events '())
       (emit (lambda (ev) (set! events (cons ev events))))
       (decoder (make-responses-stream-decoder state emit))
       (sse (string-append "event: response.output_text.delta\n"
              "data: {\"type\":\"response.output_text.delta\",\"delta\":\"Hi\"}\n\n"
              "event: response.completed\n"
              "data: {\"type\":\"response.completed\",\"response\":{\"status\":\"completed\"}}\n\n"
            ) ;string-append
       ) ;sse
      ) ;
  (decoder sse)
  (check (responses-stream-state-last-text state) => "Hi")
  (check (responses-stream-state-stop-reason state) => "stop")
  (check (pi-text-block-text (car (responses-stream-state-blocks state))) => "Hi")
) ;let*

;; extract-responses-stream-error-message
(check (extract-responses-stream-error-message "{\"error\":{\"message\":\"boom\"}}")
  =>
  "boom"
) ;check
(check (extract-responses-stream-error-message "not json") => #f)

(check-report)
