;; OAuth 401 刷新后的 access token 必须保留在原请求配置中。
;; 连续两次经协议分发发请求：第一次旧 token 收到 401，刷新后成功；
;; 第二次直接使用新 token，不得再次刷新或收到 401。
;;
;; 语法
;; ----
;; (pi-request-provider provider config msgs sys-prompt tools timeout opt-retry)
;;
;; 参数
;; ----
;; provider : string?
;; 服务商 id（kimi-coding）。
;;
;; config : <pi-config>
;; 含旧 access token 与 refresh-oauth-key 钩子的请求配置。
;;
;; msgs : list?
;; 用户消息列表。
;;
;; sys-prompt : #f
;; 本测试不使用系统提示。
;;
;; tools : list?
;; 空工具列表。
;;
;; timeout : number?
;; 单次请求超时秒数。
;;
;; opt-retry : #f
;; 使用配置中的重试设置。
;;
;; 返回值
;; ------
;; pi-assistant-message?，两次均成功；原 config 的 api-key 为新 access token。

(import (scheme base)
  (liii check)
  (liii string)
  (liii subprocess)
  (liii pi ai config model-metadata)
  (liii pi ai config runtime)
  (liii pi ai message)
  (liii pi ai dispatch)
) ;import

(check-set-mode! 'report-failed)

(define stub-file
  (if (file-exists? "tests/stub_oauth_refresh_request_server.py")
    "tests/stub_oauth_refresh_request_server.py"
    "ai/tests/stub_oauth_refresh_request_server.py"
  ) ;if
) ;define

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define (response-text resp)
  (pi-text-block-text (car (pi-assistant-message-content resp)))
) ;define

(let* ((proc (process-spawn (list "python3" stub-file) :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (base-url (string-append "http://127.0.0.1:" (number->string port)))
       (refresh-count 0)
       (cfg
         (make-pi-config
           :provider     "kimi-coding"
           :provider-api "openai-completions"
           :model-id     "kimi-for-coding"
           :model-meta
           (pi-model-metadata "kimi-for-coding" "Kimi" "kimi-coding" base-url 4096 128)
           :api-key  "old-access"
           :settings '((retry (enabled . #f)))
           :extras   (list (cons 'headers '()))
         ) ;make-pi-config
       ) ;cfg
      ) ;
  (set! cfg
    (pi-cfg-set cfg
      'refresh-oauth-key
      (lambda (config current-key)
        (set! refresh-count (+ refresh-count 1))
        (check current-key => "old-access")
        (pi-cfg-api-key-set! config "new-access")
        "new-access"
      ) ;lambda
    ) ;pi-cfg-set
  ) ;set!
  (let ((first (pi-request-provider "kimi-coding"
                 cfg
                 (list (pi-user-message "first"))
                 #f
                 '()
                 10
               ) ;pi-request-provider
        ) ;first
       ) ;
    (check (pi-assistant-message-stop-reason first) => "stop")
    (check (response-text first) => "PlainOK:new-access")
    (check refresh-count => 1)
    (check (pi-cfg-ref cfg 'api-key) => "new-access")
  ) ;let
  (let ((second (pi-request-provider "kimi-coding"
                  cfg
                  (list (pi-user-message "second"))
                  #f
                  '()
                  10
                ) ;pi-request-provider
        ) ;second
       ) ;
    (check (pi-assistant-message-stop-reason second) => "stop")
    (check (response-text second) => "PlainOK:new-access")
    (check refresh-count => 1)
    (check (pi-cfg-ref cfg 'api-key) => "new-access")
  ) ;let
  (process-kill proc)
) ;let*

(check-report)
