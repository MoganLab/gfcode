;; responses-request
;; responses-request-stream
;; Responses API 非流式/流式端到端集成测试（本地 stub 服务器）。

(import (scheme base)
  (liii check)
  (liii list)
  (liii string)
  (liii subprocess)
  (liii pi ai message)
  (liii pi ai api openai-responses)
) ;import

(check-set-mode! 'report-failed)

(define (find-stub-server)
  (let loop
    ((candidates '("ai/tests/stub_responses_server.py"
                   "tests/stub_responses_server.py"
                   "../ai/tests/stub_responses_server.py"
                   "stub_responses_server.py" "../stub_responses_server.py")
     ) ;candidates
    ) ;
    (cond ((null? candidates)
           (error 'file-not-found "stub_responses_server.py not found")
          ) ;
          ((file-exists? (car candidates)) (car candidates))
          (else (loop (cdr candidates)))
    ) ;cond
  ) ;let
) ;define

(define (response-text resp)
  (if (not (pi-assistant-message? resp))
    ""
    (let ((content (pi-assistant-message-content resp)))
      (if (pair? content)
        (let loop
          ((rest content))
          (cond ((null? rest) "")
                ((pi-text-block? (car rest)) (pi-text-block-text (car rest)))
                (else (loop (cdr rest)))
          ) ;cond
        ) ;let
        ""
      ) ;if
    ) ;let
  ) ;if
) ;define

(define (make-config base-url extra)
  (append
    (list (cons 'provider "custom-openai-responses")
      (cons 'provider-api "openai-responses")
      (cons 'model-id "gpt-6.2-astra")
      (cons 'model-meta `(("base-url" . ,base-url) ("max-tokens" . 256)))
      (cons 'api-key "test-key")
      (cons 'proxy-url #f)
      (cons 'tools '())
      (cons 'settings '((retry (enabled . #f))))
    ) ;list
    extra
  ) ;append
) ;define

(define server
  (process-spawn (list "python3" (find-stub-server)) :stdout 'pipe)
) ;define

(define port-line (process-read-line server))

(define port
  (and (string? port-line)
    (string-starts? port-line "PORT:")
    (string->number (substring port-line 5 (string-length port-line)))
  ) ;and
) ;define

(dynamic-wind (lambda () #t)
  (lambda ()
    (check-true (number? port))
    (when (number? port)
      (let ((base-url (string-append "http://127.0.0.1:" (number->string port))))
        ;; 非流式：文本响应
        (let ((resp (responses-request (make-config base-url '())
                      (list (pi-user-message "hi"))
                      #f
                      '()
                      10
                      #f
                    ) ;responses-request
              ) ;resp
             ) ;
          (check (pi-assistant-message-stop-reason resp) => "stop")
          (check (pi-assistant-message-api resp) => "openai-responses")
          (check (response-text resp) => "PONG")
        ) ;let

        ;; 流式：文本响应
        (let ((resp (responses-request-stream (make-config base-url '())
                      (list (pi-user-message "hi"))
                      #f
                      '()
                      #f
                      10
                      #f
                    ) ;responses-request-stream
              ) ;resp
             ) ;
          (check (pi-assistant-message-stop-reason resp) => "stop")
          (check (response-text resp) => "PONG")
        ) ;let

        ;; 流式：工具调用（首轮返回 function_call）
        (let* ((events '())
               (resp
                 (responses-request-stream (make-config base-url '())
                   (list (pi-user-message "please use tool"))
                   #f
                   '()
                   (lambda (ev) (set! events (cons ev events)))
                   10
                   #f
                 ) ;responses-request-stream
               ) ;resp
              ) ;
          (check (pi-assistant-message-stop-reason resp) => "toolUse")
          (let ((tool-blocks (filter pi-tool-call-block? (pi-assistant-message-content resp))))
            (check (length tool-blocks) => 1)
            (check (pi-tool-call-block-name (car tool-blocks)) => "bash")
          ) ;let
        ) ;let*

        ;; usage 映射结构可读（本地 stub 不注入 prompt_cache_key，
        ;; 因为该字段仅对 api.openai.com 官方端点注入）
        (let* ((cfg (make-config base-url (list (cons 'session-id "sess-123"))))
               (resp (responses-request cfg (list (pi-user-message "hi")) #f '() 10 #f))
              ) ;
          (check (pi-assistant-message? resp) => #t)
          (check (pi-assistant-message-stop-reason resp) => "stop")
        ) ;let*
      ) ;let
    ) ;when
  ) ;lambda
  (lambda () (process-kill server))
) ;dynamic-wind

(check-report)
