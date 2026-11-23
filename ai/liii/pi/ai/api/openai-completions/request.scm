;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi ai api openai-completions request)
  (import (scheme base)
    (scheme write)
    (scheme char)
    (liii string)
    (liii list)
    (liii uri)
    (liii json)
    (liii http)
    (liii uuid)
    (liii error)
    (liii time)
    (liii pi ai config model-metadata)
    (liii pi ai config runtime)
    (liii pi ai message)
    (liii pi ai api openai-completions core)
    (liii pi ai api openai-completions msg)
    (liii pi ai api openai-completions thinking)
    (liii pi ai retry)
    (liii pi ai limits)
    (liii pi ai log)
    (liii pi ai keyring)
  ) ;import
  (export openai-build-tool-declarations-from-names openai-request
    openai-build-endpoint openai-build-headers openai-build-proxy-alist
  ) ;export
  (begin

    (define (%resp-field resp key)
      (cond ((procedure? resp) (resp key))
            ((hash-table? resp) (resp key))
            ((pair? resp) (cdr (or (assoc key resp) '(#f . #f))))
            (else #f)
      ) ;cond
    ) ;define

    ;; 1404：取 token 末 4 位用于日志，不泄露完整 token；空/短串安全
    (define (%token-tail s)
      (if (and (string? s) (> (string-length s) 0))
        (let ((n (string-length s)))
          (substring s (max 0 (- n 4)) n))
        "")
    ) ;define

    ;; 1404：oauth 401 强制刷新结果描述（用于日志），不暴露完整 token
    (define (%oauth-refresh-result-desc next)
      (cond ((string? next)
             (string-append "ok new-token=..." (%token-tail next)))
            ((eq? next 'unauthorized) "unauthorized")
            (else "none"))
    ) ;define

    ;; 1404：写一行 [oauth-401] 日志到 ~/.gf/agent/logs/pi-YYYY-MM-DD.log
    (define (%log-oauth-401 provider attempt api-key next)
      (pi-log-error!
        (string-append "[oauth-401] provider=" (or provider "")
          " attempt=" (number->string attempt)
          " old-token=..." (%token-tail api-key)
          " refresh=" (%oauth-refresh-result-desc next))
      ) ;pi-log-error!
    ) ;define

    ;; 401 报错结算：解析响应体构造 assistant 消息（oauth 刷新失败或重试耗尽后复用）
    (define (%parse-401-response body-str status provider model-id)
      (let* ((parsed-json (catch #t (lambda () (string->json body-str)) (lambda args #f))))
        (openai-parse-response parsed-json status provider model-id
          "openai-completions"
        ) ;openai-parse-response
      ) ;let*
    ) ;define

    (define (openai-build-endpoint base-url)
      (let* ((u (make-uri (or base-url "https://api.openai.com/v1")))
             (raw-path (or (uri-path u) ""))
             (path
               (if (string-ends? raw-path "/")
                 (substring raw-path 0 (- (string-length raw-path) 1))
                 raw-path
               ) ;if
             ) ;path
            ) ;
        (cond ((string-ends? path "/chat/completions") (uri->string (uri-with-path u path)))
              ((or (string-ends? path "/v1")
                 (string-ends? path "/v4")
                 (string-contains? path "/paas/")
               ) ;or
               (uri->string (uri-join-path u "chat" "completions"))
              ) ;
              (else (uri->string (uri-join-path u "v1" "chat" "completions")))
        ) ;cond
      ) ;let*
    ) ;define

    (define* (openai-build-headers api-key (extra-headers '()))
      (unless (or (string? api-key) (not api-key))
        (type-error "openai-build-headers: api-key must be a string or #f" api-key)
      ) ;unless
      (let ((base
              (list (cons "Content-Type" "application/json")
                (cons "Authorization" (string-append "Bearer " (or api-key "")))
                (cons "User-Agent" "Goldfish-Pi/1.0")
              ) ;list
            ) ;base
            ;; 延迟展开 ${API_KEY}：每次尝试（含密钥轮换）使用本次 api-key。
            (extras
              (map
                (lambda (h)
                  (unless (and (pair? h) (string? (car h)) (string? (cdr h)))
                    (type-error "openai-build-headers: expected (string . string) header" h)
                  ) ;unless
                  (cons (car h) (string-replace (cdr h) "${API_KEY}" (or api-key "")))
                ) ;lambda
                extra-headers
              ) ;map
            ) ;extras
           ) ;
        (append
          (filter
            (lambda (h)
              (not
                (find (lambda (extra) (string-ci=? (car h) (car extra))) extras)
              ) ;not
            ) ;lambda
            base
          ) ;filter
          extras
        ) ;append
      ) ;let
    ) ;define*

    (define (%openai-extra-headers url provider session-id config settings)
      (let* ((cfg-hdrs (or (pi-cfg-ref config 'headers) '()))
             (set-hdrs
               (or
                 (and (pair? settings) (cdr (or (assoc 'headers settings) '(#f
                                                                            . #f))))
                 '()
               ) ;or
             ) ;set-hdrs
             (opencode-hdrs
               (if
                 (or (and (string? url) (string-contains? url "opencode.ai"))
                   (and (string? provider)
                     (or (string=? provider "opencode") (string=? provider "opencode-go"))
                   ) ;and
                 ) ;or
                 (list
                   (cons "x-opencode-session"
                     (if (and (string? session-id) (> (string-length session-id) 0))
                       session-id
                       (uuid4)
                     ) ;if
                   ) ;cons
                 ) ;list
                 '()
               ) ;if
             ) ;opencode-hdrs
            ) ;
        (append cfg-hdrs set-hdrs opencode-hdrs)
      ) ;let*
    ) ;define

    (define (openai-build-proxy-alist proxy-url)
      (if (and (string? proxy-url) (not (string-null? proxy-url)))
        (list (cons "http" proxy-url) (cons "https" proxy-url))
        '()
      ) ;if
    ) ;define

    (define (openai-build-tool-declarations-from-names active-tool-names tool-resolver)
      (openai-build-tool-declarations (filter (lambda (d) d) (map tool-resolver (or active-tool-names '())))
      ) ;openai-build-tool-declarations
    ) ;define

    (define (%resolve-retry-params settings opt-retry)
      (pi-resolve-retry-params settings opt-retry)
    ) ;define

    (define (%request-error-text status attempt body-str reason)
      (if (zero? status)
        (let ((detail (if (string? reason) (string-trim-both reason) "")))
          (cond ((string-null? detail) "Request failed: network error")
                ((string-starts? detail "Request timed out") detail)
                (else (string-append "Request failed: " detail))
          ) ;cond
        ) ;let
        (string-append "HTTP "
          (number->string status)
          " after "
          (number->string attempt)
          " attempts: "
          body-str
        ) ;string-append
      ) ;if
    ) ;define

    (define (%make-retry-error status attempt body-str provider model-id reason)
      (let ((limit (pi-usage-limit-error? status body-str provider)))
        (pi-assistant-message (list (pi-text-block ""))
          :stop-reason "error"
          :error-message
          (if limit
            (pi-usage-limit-error-message limit provider)
            (%request-error-text status attempt body-str reason)
          ) ;if
          :usage    (openai-map-usage '())
          :provider provider
          :model    model-id
          :api      "openai-completions"
        ) ;pi-assistant-message
      ) ;let
    ) ;define

    (define (%post-openai url req-json-str headers proxy-alist timeout)
      (catch #t
        (lambda ()
          (http-post url
            :data    req-json-str
            :headers headers
            :proxy   proxy-alist
            :timeout timeout
          ) ;http-post
        ) ;lambda
        (lambda (tag . args)
          (if (eq? tag 'http-client-timeout-error)
            (let ((msg (string-append "Request timed out after " (number->string timeout) "s")))
              (list (cons 'status-code 0)
                (cons 'reason msg)
                (cons 'text "")
                (cons 'timeout #t)
                (cons 'timeout-sec timeout)
              ) ;list
            ) ;let
            (let ((err-msg (if (pair? args) (car args) "Network error")))
              (list (cons 'status-code 0) (cons 'reason err-msg) (cons 'text ""))
            ) ;let
          ) ;if
        ) ;lambda
      ) ;catch
    ) ;define

    (define* (openai-request config
               messages
               (system-instruction #f)
               (tool-names #f)
               (timeout 300)
               (opt-retry #f)
             ) ;openai-request
      (let*-values (((model-id) (pi-cfg-ref config 'model-id))
                    ((model-meta) (pi-cfg-ref config 'model-meta))
                    ((proxy-url) (pi-cfg-ref config 'proxy-url))
                    ((settings) (pi-cfg-ref config 'settings))
                    ((provider) (pi-cfg-ref config 'provider))
                    ((thinking-level) (pi-cfg-ref config 'thinking-level))
                    ((model-entry)
                     (openai-resolve-model-entry (pi-cfg-ref config 'models-store '())
                       provider
                       model-id
                     ) ;openai-resolve-model-entry
                    ) ;
                    ((max-retries base-delay max-delay provider-max-retries)
                     (%resolve-retry-params settings opt-retry)
                    ) ;
                    ((base-url)
                     (cond ((pi-model-metadata? model-meta) (pi-model-metadata-base-url model-meta))
                           ((pair? model-meta)
                            (cdr (or (assoc 'base-url model-meta)
                                   (assoc "base-url" model-meta)
                                   '(#f . "https://api.openai.com/v1")
                                 ) ;or
                            ) ;cdr
                           ) ;
                           (else "https://api.openai.com/v1")
                     ) ;cond
                    ) ;
                    ((max-tokens)
                     (cond ((pi-model-metadata? model-meta)
                            (or (pi-model-metadata-max-tokens model-meta) 8192)
                           ) ;
                           ((pair? model-meta)
                            (cdr (or (assoc 'max-tokens model-meta) (assoc "max-tokens" model-meta) '(#f
                                                                                                      . 8192))
                            ) ;cdr
                           ) ;
                           (else 8192)
                     ) ;cond
                    ) ;
                    ((url) (openai-build-endpoint base-url))
                    ((eff-tool-names) (or tool-names (pi-cfg-ref config 'tools '())))
                    ((tool-resolver) (or (pi-cfg-ref config 'tool-resolver) (lambda (name) #f)))
                    ((tool-decls)
                     (openai-build-tool-declarations-from-names eff-tool-names tool-resolver)
                    ) ;
                    ((prompt-cache-key)
                     (openai-resolve-prompt-cache-key base-url (pi-cfg-ref config 'session-id))
                    ) ;
                    ((openai-msgs) (openai-build-messages messages system-instruction))
                    ((req-body)
                     (openai-build-request-body model-id openai-msgs #f
                       tool-decls max-tokens prompt-cache-key thinking-level
                       model-entry
                     ) ;openai-build-request-body
                    ) ;
                    ((req-json-str) (json->string req-body))
                    ((proxy-alist) (openai-build-proxy-alist proxy-url))
                   ) ;
        (let ((key-rotation? (pi-key-rotation? config))
              (session-id (pi-cfg-ref config 'session-id))
             ) ;
          (let loop
            ((attempt 1) (api-key (pi-request-api-key config))
             (refreshed-once? #f))
            (let* ((extra-hdrs (%openai-extra-headers url provider session-id config settings))
                   (headers (openai-build-headers api-key extra-hdrs))
                   (resp (%post-openai url req-json-str headers proxy-alist timeout))
                   (status (or (%resp-field resp 'status-code) 0))
                   (body-str (or (%resp-field resp 'text) ""))
                  ) ;
              ;; 异常请求（非 200）连同响应体原文落盘，便于事后排障
              (when (not (= status 200))
                (pi-log-http-error! status
                  body-str
                  (list (cons 'provider provider)
                    (cons 'model model-id)
                    (cons 'url (string-append "POST " url))
                    (cons 'attempt attempt)
                    (cons 'max-attempts provider-max-retries)
                    (cons 'retryable (openai-is-retriable-error? status body-str provider))
                    (cons 'reason (%resp-field resp 'reason))
                  ) ;list
                ) ;pi-log-http-error!
              ) ;when
              (cond
               ((and key-rotation? (or (= status 429) (= status 403)))
                (let ((next (pi-rotate-api-key! config api-key status)))
                  (if (eq? next 'exhausted)
                    (%make-retry-error status
                      1
                      body-str
                      provider
                      model-id
                      (%resp-field resp 'reason)
                    ) ;%make-retry-error
                    (loop 1 next refreshed-once?)
                  ) ;if
                ) ;let
               ) ;
               ((openai-is-retriable-error? status body-str provider)
                (if (<= attempt provider-max-retries)
                  (let* ((ra-raw (pi-extract-retry-after resp))
                         (ra-sec (pi-parse-retry-after ra-raw))
                         (delay-sec (pi-calc-retry-delay attempt base-delay max-delay ra-sec))
                         (retry-status (if (%resp-field resp 'timeout) (%resp-field resp 'reason) status)
                         ) ;retry-status
                        ) ;
                    (pi-log-retry retry-status attempt provider-max-retries delay-sec ra-sec)
                    (sleep delay-sec)
                    (loop (+ attempt 1) api-key refreshed-once?)
                  ) ;let*
                  (%make-retry-error status
                    attempt
                    body-str
                    provider
                    model-id
                    (%resp-field resp 'reason)
                  ) ;%make-retry-error
                ) ;if
               ) ;
               ;; 1404：oauth 凭据收到 401 后强制刷新重试一次（仅一次）。
               ;; 服务端可能在本地 expires 之前判 access token 失效返回 401，
               ;; 此时请求层回退强制 refresh 换取新 token 重试；refresh 失败
               ;; （401/403/invalid_grant）凭据已清除，走 401 报错提示重 /login。
               ((and (= status 401)
                  (pi-oauth-refresh-enabled? config)
                  (not refreshed-once?))
                (let ((next (pi-refresh-oauth-key! config api-key)))
                  (%log-oauth-401 provider attempt api-key next)
                  (if (string? next)
                    (loop 1 next #t)
                    (%parse-401-response body-str status provider model-id)
                  ) ;if
                ) ;let
               ) ;
               (else
                 (let* ((parsed-json (catch #t (lambda () (string->json body-str)) (lambda args #f)))
                        (limit (pi-usage-limit-error? status body-str provider))
                       ) ;
                   (if limit
                     (pi-assistant-message (list (pi-text-block ""))
                       :stop-reason "error"
                       :usage       (openai-map-usage '())
                       :error-message
                       (pi-usage-limit-error-message limit provider)
                       :provider provider
                       :model    model-id
                       :api      "openai-completions"
                     ) ;pi-assistant-message
                     (openai-parse-response parsed-json status provider model-id
                       "openai-completions"
                     ) ;openai-parse-response
                   ) ;if
                 ) ;let*
               ) ;else
              ) ;cond
            ) ;let*
          ) ;let
        ) ;let
      ) ;let*-values
    ) ;define*

  ) ;begin
) ;define-library
