;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; Kimi Code（订阅）OAuth2 设备码流程，翻译自上游 pi 仓库（本地 ~/git/pi）
;; packages/ai/src/auth/oauth/kimi-coding.ts：RFC 8628 设备授权 +
;; refresh_token 刷新，端点 {host}/api/oauth/device_authorization 与
;; {host}/api/oauth/token，access token 作 Bearer 用于 api.kimi.com/coding。
;; 默认国内 host auth.kimi.com，KIMI_CODE_OAUTH_HOST / KIMI_OAUTH_HOST 可覆盖
;; （海外 auth.kimi.ai，账号体系不互通，见 pi issue #9819）。
(define-library (liii pi ai auth oauth kimi-coding-oauth)
  (import (scheme base)
    (scheme inexact)
    (scheme process-context)
    (liii string)
    (liii list)
    (liii error)
    (liii http)
    (liii json)
    (liii uri)
    (liii time)
    (liii pi ai time)
    (liii pi ai template)
    (liii pi ai config credential)
    (liii pi ai auth oauth device-flow)
  ) ;import
  (export KIMI_OAUTH_CLIENT_ID
    KIMI_OAUTH_DEFAULT_HOST
    kimi-oauth-host
    kimi-device-authorize
    kimi-poll-token
    kimi-refresh-token
    kimi-oauth-login
    kimi-oauth->auth
    kimi-device-authorization?
    kimi-device-authorization-device-code
    kimi-device-authorization-user-code
    kimi-device-authorization-verification-uri
    kimi-device-authorization-verification-uri-complete
    kimi-device-authorization-interval-seconds
    kimi-device-authorization-expires-in-seconds
    ;; go worker 会话只能看到导出绑定：worker 调用链上的助手须导出
    ;; （对齐 tui interactive worker 的导出缘由）
    %kimi-parse-token-response
    %kimi-trusted-http-url
    %kimi-post-form
    %kimi-token-request-fields
  ) ;export
  (begin

    (define KIMI_OAUTH_CLIENT_ID "17e5f671-d194-4dfb-9706-5516cb48c098")
    (define KIMI_OAUTH_DEFAULT_HOST "https://auth.kimi.com")
    (define %device-code-timeout-seconds (* 15 60))
    (define %default-poll-interval-seconds 5)
    (define %request-timeout-seconds 30)
    (define %refresh-max-retries 3)

    ;; 设备授权响应记录（对应 pi 的 DeviceAuthorization）
    (define-record-type <kimi-device-authorization>
      (%make-kimi-device-authorization device-code user-code verification-uri
        verification-uri-complete interval-seconds expires-in-seconds
      ) ;%make-kimi-device-authorization
      kimi-device-authorization?
      (device-code kimi-device-authorization-device-code)
      (user-code kimi-device-authorization-user-code)
      (verification-uri kimi-device-authorization-verification-uri)
      (verification-uri-complete kimi-device-authorization-verification-uri-complete)
      (interval-seconds kimi-device-authorization-interval-seconds)
      (expires-in-seconds kimi-device-authorization-expires-in-seconds)
    ) ;define-record-type

    ;; OAuth host：KIMI_CODE_OAUTH_HOST > KIMI_OAUTH_HOST > 默认国内 host，
    ;; 去掉尾部斜杠（对应 pi getOauthHost）。opt-env 为 '((name . value) ...)
    (define (kimi-oauth-host . opt-env)
      (let* ((override (or (%non-empty-env "KIMI_CODE_OAUTH_HOST" opt-env)
                         (%non-empty-env "KIMI_OAUTH_HOST" opt-env)
                       ) ;or
             ) ;override
             (host (or override KIMI_OAUTH_DEFAULT_HOST))
            ) ;
        (string-trim-right host #\/)
      ) ;let*
    ) ;define

    ;; opt-env 是 variadic 参数列表；调用方给出 env-alist 时，保留完整
    ;; alist 并包成 lookup-env-var 需要的 (env-alist) 形态。
    (define (%non-empty-env name opt-env)
      (let ((v (lookup-env-var name (if (pair? opt-env) (list (car opt-env)) '()))))
        (and (string? v) (not (string-null? (string-trim-both v))) (string-trim-both v))
      ) ;let
    ) ;define

    ;; 仅信任 http/https 绝对 URL（对应 pi trustedHttpUrl）：登录流程会把
    ;; 服务端返回的 URL 交给浏览器打开，必须挡掉 file: 等自定义协议与
    ;; 控制字符；这里比 pi 更严格，含控制字符直接拒绝
    (define (%kimi-trusted-http-url value)
      (and (string? value)
        (or (string-starts? value "https://") (string-starts? value "http://"))
        (not (string-any (lambda (c) (char<? c #\space)) value))
        value
      ) ;and
    ) ;define

    ;; 表单编码 POST（application/x-www-form-urlencoded），网络错误/超时
    ;; 归一为 status-code 0 的响应对象，交由调用方按状态分类
    (define (%kimi-post-form url fields)
      (catch #t
        (lambda ()
          (http-post url
            :data
            (string-join
              (map
                (lambda (pair)
                  (string-append (uri-encode (car pair)) "=" (uri-encode (cdr pair)))
                ) ;lambda
                fields
              ) ;map
              "&"
            ) ;string-join
            :headers
            '(("Content-Type" . "application/x-www-form-urlencoded")
              ("Accept" . "application/json"))
            :timeout %request-timeout-seconds
          ) ;http-post
        ) ;lambda
        (lambda (tag . args)
          (list (cons 'status-code 0)
            (cons 'reason
              (if (pair? args) (object->string (car args)) (symbol->string tag))
            ) ;cons
            (cons 'text "")
          ) ;list
        ) ;lambda
      ) ;catch
    ) ;define

    (define (%resp-field resp key)
      (cond ((procedure? resp) (resp key))
            ((hash-table? resp) (resp key))
            ((pair? resp) (cdr (or (assoc key resp) '(#f . #f))))
            (else #f)
      ) ;cond
    ) ;define

    (define (%read-json resp)
      (let ((text (%resp-field resp 'text)))
        (and (string? text)
          (catch #t
            (lambda () (let ((j (string->json text))) (and (pair? j) j)))
            (lambda args #f)
          ) ;catch
        ) ;and
      ) ;let
    ) ;define

    ;; POST {host}/api/oauth/device_authorization，grant 为 RFC 8628 设备授权
    (define (kimi-device-authorize host)
      (let* ((resp (%kimi-post-form (string-append host "/api/oauth/device_authorization")
                     (list (cons "client_id" KIMI_OAUTH_CLIENT_ID))
                   ) ;%kimi-post-form
             ) ;resp
             (status (or (%resp-field resp 'status-code) 0))
             (body (or (%resp-field resp 'text) ""))
            ) ;
        (unless (and (>= status 200) (< status 300))
          (error 'kimi-oauth-error
            (string-append "Kimi Code device authorization failed with status "
              (number->string status)
              (if (string-null? body) "" (string-append ": " body))
            ) ;string-append
          ) ;error
        ) ;unless
        (let* ((json (%read-json resp))
               (device-code (and json (json-ref-string json "device_code" #f)))
               (user-code (and json (json-ref-string json "user_code" #f)))
               (verification-uri (%kimi-trusted-http-url (and json (json-ref json "verification_uri")))
               ) ;verification-uri
               (verification-uri-complete (%kimi-trusted-http-url (and json (json-ref json "verification_uri_complete")))
               ) ;verification-uri-complete
               (interval (and json (json-ref-number json "interval" #f)))
               (expires-in (and json (json-ref-number json "expires_in" #f)))
              ) ;
          (unless (and device-code user-code verification-uri verification-uri-complete)
            (error 'kimi-oauth-error
              (string-append "Invalid Kimi Code device authorization response: " body)
            ) ;error
          ) ;unless
          (%make-kimi-device-authorization device-code
            user-code
            verification-uri
            verification-uri-complete
            (if (and (number? interval) (finite? interval) (> interval 0))
              interval
              %default-poll-interval-seconds
            ) ;if
            (if (and (number? expires-in) (finite? expires-in) (> expires-in 0))
              expires-in
              %device-code-timeout-seconds
            ) ;if
          ) ;%make-kimi-device-authorization
        ) ;let*
      ) ;let*
    ) ;define

    ;; token 响应解析（对应 pi parseTokenResponse）：返回 pi-credential
    ;; oauth 记录，expires 为毫秒 epoch（Date.now() + expires_in * 1000）
    (define (%kimi-parse-token-response json operation provider region)
      (let ((access (and json (json-ref-string json "access_token" #f)))
            (refresh (and json (json-ref-string json "refresh_token" #f)))
            (expires-in (and json (json-ref-number json "expires_in" #f)))
           ) ;
        (unless (and access
                  (not (string-null? access))
                  refresh
                  (not (string-null? refresh))
                  (number? expires-in)
                  (finite? expires-in)
                  (> expires-in 0)
                ) ;and
          (error 'kimi-oauth-error
            (string-append "Kimi Code token "
              operation
              " response missing fields: "
              (if json (json->string json) "null")
            ) ;string-append
          ) ;error
        ) ;unless
        (pi-credential provider
          #f
          "oauth"
          access
          refresh
          (+ (pi-current-time-millis) (* expires-in 1000))
          region
        ) ;pi-credential
      ) ;let
    ) ;define

    (define (%kimi-token-request-fields device-code)
      (list (cons "client_id" KIMI_OAUTH_CLIENT_ID)
        (cons "device_code" device-code)
        (cons "grant_type" "urn:ietf:params:oauth:grant-type:device_code")
      ) ;list
    ) ;define

    ;; 单次轮询：把 HTTP 响应映射为 device-flow 四态协议
    (define (%kimi-poll-once host device-code provider region)
      (let* ((resp (%kimi-post-form (string-append host "/api/oauth/token")
                     (%kimi-token-request-fields device-code)
                   ) ;%kimi-post-form
             ) ;resp
             (status (or (%resp-field resp 'status-code) 0))
             (json (%read-json resp))
            ) ;
        (cond
         ((>= status 500)
          (let ((body (or (%resp-field resp 'text) "")))
            (list 'failed
              (string-append "Kimi Code device token request failed with status "
                (number->string status)
                (if (string-null? body) "" (string-append ": " body))
              ) ;string-append
            ) ;list
          ) ;let
         ) ;
         ((and (>= status 200)
            (< status 300)
            json
            (string? (json-ref-string json "access_token" #f))
          ) ;and
          (catch 'kimi-oauth-error
            (lambda ()
              (list 'complete (%kimi-parse-token-response json "poll" provider region))
            ) ;lambda
            (lambda (tag msg) (list 'failed msg))
          ) ;catch
         ) ;
         (else
           (let* ((err (and json (json-ref-string json "error" #f)))
                  (desc (and json (json-ref-string json "error_description" #f)))
                  (description (if desc (string-append ": " desc) ""))
                 ) ;
             (cond ((equal? err "authorization_pending") '(pending))
                   ((equal? err "slow_down")
                    (let ((interval (and json (json-ref-number json "interval" #f))))
                      (list 'slow_down (and (number? interval) (> interval 0) interval))
                    ) ;let
                   ) ;
                   ((equal? err "expired_token")
                    '(failed "Kimi Code device authorization expired. Please restart login.")
                   ) ;
                   ((equal? err "access_denied") '(failed "Kimi Code login was denied."))
                   (else
                     (list 'failed
                       (string-append "Kimi Code device token request failed (status "
                         (number->string status)
                         ")"
                         (if err (string-append ": " err description) "")
                       ) ;string-append
                     ) ;list
                   ) ;else
             ) ;cond
           ) ;let*
         ) ;else
        ) ;cond
      ) ;let*
    ) ;define

    ;; 轮询直至授权完成/失败/超时/取消。notify 收到 device_code 事件
    ;; （user-code verification-uri-complete interval expires），cancelled?
    ;; 谓词由 TUI 组件层置位
    (define* (kimi-poll-token host device provider region (cancelled? #f))
      (pi-device-flow-poll (lambda ()
                             (%kimi-poll-once host
                               (kimi-device-authorization-device-code device)
                               provider
                               region
                             ) ;%kimi-poll-once
                           ) ;lambda
        (kimi-device-authorization-interval-seconds device)
        (kimi-device-authorization-expires-in-seconds device)
        #t
        cancelled?
      ) ;pi-device-flow-poll
    ) ;define*

    ;; refresh_token 刷新，429/5xx/网络错误指数退避重试 3 次
    ;; （1s/2s/4s）；401/403/invalid_grant 抛 kimi-oauth-unauthorized，
    ;; 调用方据此清除凭据并提示重新 /login
    (define (kimi-refresh-token host refresh-token provider region)
      (let loop
        ((attempt 0) (last-error "Kimi Code token refresh failed"))
        (when (> attempt 0)
          (sleep (expt 2 (- attempt 1)))
        ) ;when
        (let* ((resp (%kimi-post-form (string-append host "/api/oauth/token")
                       (list (cons "client_id" KIMI_OAUTH_CLIENT_ID)
                         (cons "grant_type" "refresh_token")
                         (cons "refresh_token" refresh-token)
                       ) ;list
                     ) ;%kimi-post-form
               ) ;resp
               (status (or (%resp-field resp 'status-code) 0))
               (json (%read-json resp))
              ) ;
          (cond ((and (>= status 200) (< status 300))
                 (%kimi-parse-token-response json "refresh" provider region)
                ) ;
                ((or (= status 401)
                   (= status 403)
                   (and json (equal? (json-ref-string json "error" #f) "invalid_grant"))
                 ) ;or
                 (let ((desc (and json (json-ref-string json "error_description" #f))))
                   (error 'kimi-oauth-unauthorized
                     (string-append "Kimi Code token refresh unauthorized (status "
                       (number->string status)
                       ")"
                       (if desc (string-append ": " desc) "")
                     ) ;string-append
                   ) ;error
                 ) ;let
                ) ;
                ((and (or (= status 429) (>= status 500) (= status 0))
                   (< attempt %refresh-max-retries)
                 ) ;and
                 (loop (+ attempt 1)
                   (string-append "Kimi Code token refresh failed with status "
                     (number->string status)
                   ) ;string-append
                 ) ;loop
                ) ;
                (else
                  (error 'kimi-oauth-error
                    (string-append "Kimi Code token refresh failed with status "
                      (number->string status)
                      (if json (string-append ": " (json->string json)) "")
                    ) ;string-append
                  ) ;error
                ) ;else
          ) ;cond
        ) ;let*
      ) ;let
    ) ;define

    ;; 完整登录：设备授权 → notify device_code 事件 → 轮询换 token。
    ;; 返回 pi-credential oauth 记录；region 仅在 env 覆盖 host 时记录
    ;; （默认 host 不写 region，1402 §7）
    (define* (kimi-oauth-login
               (notify #f)
               (cancelled? #f)
               (provider "kimi-coding")
               .
               opt-env
             ) ;
      (let* ((host (kimi-oauth-host (if (pair? opt-env) (car opt-env) '())))
             (region (and (not (string=? host KIMI_OAUTH_DEFAULT_HOST)) host))
             (device (kimi-device-authorize host))
            ) ;
        (when notify
          (notify (list 'device_code
                    (kimi-device-authorization-user-code device)
                    (kimi-device-authorization-verification-uri-complete device)
                    (kimi-device-authorization-interval-seconds device)
                    (kimi-device-authorization-expires-in-seconds device)
                  ) ;list
          ) ;notify
        ) ;when
        (kimi-poll-token host device provider region cancelled?)
      ) ;let*
    ) ;define*

    ;; 凭据 → 请求头（对应 pi toAuth()）：Bearer access token，
    ;; openai-completions 的 openai-build-headers 与此等价
    (define (kimi-oauth->auth credential)
      (unless (pi-credential-oauth? credential)
        (type-error "kimi-oauth->auth: expected oauth pi-credential" credential)
      ) ;unless
      (list (cons "Authorization"
              (string-append "Bearer " (pi-credential-access credential))
            ) ;cons
      ) ;list
    ) ;define

  ) ;begin
) ;define-library
