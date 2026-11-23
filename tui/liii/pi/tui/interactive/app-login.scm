;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; /login 交互：解析登录命令、唤起供应商选择器或 Key 输入对话框、持久化凭证至 auth.json；
;; kimi-coding 的 OAuth 路径：二级选择后后台 go worker 跑设备码流程，
;; device_code/done 事件经 event-chan 回到主线程上屏与落盘（1402 §5.4）
(define-library (liii pi tui interactive app-login)
  (export pi-app-login-command?
    pi-app-submit-login!
    pi-app-show-login-oauth!
    pi-app-handle-oauth-device-code!
    pi-app-handle-oauth-done!
    ;; go worker 会话只能看到导出绑定：worker 调用链上的助手须导出
    %kimi-oauth-login-worker
  ) ;export
  (import (scheme base)
    (liii go)
    (liii string)
    (liii list)
    (liii path)
    (liii error)
    (liii tui)
    (liii tui component)
    (liii pi ai auth)
    (liii pi ai config credential)
    (liii pi ai auth oauth kimi-coding-oauth)
    (liii pi code config)
    (liii pi tui interactive state)
    (liii pi tui interactive render)
    (liii pi tui interactive views)
    (liii pi tui interactive login-selector)
    (liii pi tui interactive login-dialog)
    (liii pi tui interactive login-device-code)
  ) ;import
  (begin

    (define (pi-app-login-command? text)
      (or (string=? text "/login") (string-starts? text "/login "))
    ) ;define

    (define (pi-app-close-login! app)
      (%pi-app-active-selector-set! app #f)
      (editor-set-focused! (pi-app-editor app) #t)
      (pi-app-render! app)
    ) ;define

    (define* (pi-app-save-login-key! app provider key (opt-config-dir #f))
      (let* ((cfg-dir (or opt-config-dir (gf-get-config-dir)))
             (saved-path (catch #t
                           (lambda () (pi-save-auth-key provider key cfg-dir))
                           (lambda (tag . info) #f)
                         ) ;catch
             ) ;saved-path
            ) ;
        (%pi-app-active-selector-set! app #f)
        (editor-set-focused! (pi-app-editor app) #t)
        (if saved-path
          (begin
            (when (pi-app-jobs-chan app)
              (catch #t
                (lambda ()
                  (chan-send! (pi-app-jobs-chan app)
                    (list 'reload_models (path->string (path cfg-dir)))
                    1000
                  ) ;chan-send!
                ) ;lambda
                (lambda args #f)
              ) ;catch
            ) ;when
            (container-add! (%pi-app-chat app)
              (make-assistant-card (string-append "Saved API key for " provider " to " saved-path)
              ) ;make-assistant-card
            ) ;container-add!
          ) ;begin
          (container-add! (%pi-app-chat app)
            (make-tool-card "login"
              '()
              'error
              (string-append "Failed to save API key for " provider)
            ) ;make-tool-card
          ) ;container-add!
        ) ;if
        (pi-app-scroll-bottom! app)
        (pi-app-render! app)
      ) ;let*
    ) ;define*

    (define* (pi-app-show-login-dialog! app provider (opt-config-dir #f))
      (editor-set-focused! (pi-app-editor app) #f)
      (%pi-app-active-selector-set! app
        (make-login-dialog provider
          (lambda (key) (pi-app-save-login-key! app provider key opt-config-dir))
          (lambda () (pi-app-close-login! app))
        ) ;make-login-dialog
      ) ;%pi-app-active-selector-set!
      (pi-app-render! app)
    ) ;define*

    (define* (pi-app-show-login-selector! app (opt-config-dir #f))
      (let ((cfg-dir (or opt-config-dir (gf-get-config-dir))))
        (editor-set-focused! (pi-app-editor app) #f)
        (%pi-app-active-selector-set! app
          (make-login-selector (lambda (provider) (pi-app-show-login-dialog! app provider cfg-dir))
            (lambda () (pi-app-close-login! app))
            :current    (pi-app-provider app)
            :config-dir cfg-dir
            :on-select-method
            (lambda (provider method)
              (if (string=? method "oauth")
                (pi-app-show-login-oauth! app provider cfg-dir)
                (pi-app-show-login-dialog! app provider cfg-dir)
              ) ;if
            ) ;lambda
          ) ;make-login-selector
        ) ;%pi-app-active-selector-set!
        (pi-app-render! app)
      ) ;let
    ) ;define*

    ;; ---------- OAuth 设备码登录（kimi-coding 订阅） ----------

    ;; 启动占位组件：设备授权请求在后台 worker 中发出，device_code 事件
    ;; 到达后替换为真正的 login-device-code 组件。go 只能传可序列化数据
    ;; （app record 含闭包不可传），取消信号经独立 cancel-chan 传递
    (define* (pi-app-show-login-oauth! app provider (opt-config-dir #f))
      (let ((cfg-dir
              (path->string (path (or opt-config-dir (gf-get-config-dir))))
            ) ;cfg-dir
            (oauth-host (kimi-oauth-host))
            (cancel-chan (make-chan 1))
           ) ;
        (editor-set-focused! (pi-app-editor app) #f)
        (%pi-app-active-selector-set! app
          (make-component
            :render
            (lambda (comp width)
              (list (string-append "Login to " provider " with Kimi Code (subscription)")
                ""
                "Contacting Kimi Code for a device code…"
                ""
                "  esc to cancel"
              ) ;list
            ) ;lambda
            :handle-input
            (lambda (comp key)
              (if (memq key '(escape ctrl-c))
                (begin
                  (catch #t (lambda () (chan-try-send! cancel-chan 'cancel)) (lambda args #f))
                  (pi-app-close-login! app)
                  #t
                ) ;begin
                #f
              ) ;if
            ) ;lambda
          ) ;make-component
        ) ;%pi-app-active-selector-set!
        (go (%kimi-oauth-login-worker provider
              cfg-dir
              oauth-host
              (pi-app-event-chan app)
              cancel-chan
            ) ;%kimi-oauth-login-worker
        ) ;go
        (pi-app-render! app)
      ) ;let
    ) ;define*

    ;; 后台 worker：设备授权 → device_code 事件 → 轮询 → done 事件。
    ;; 取消探测：主线程 Esc 时向 cancel-chan 发信号（非阻塞探测）
    (define (%kimi-oauth-login-worker provider cfg-dir oauth-host event-chan cancel-chan)
      (define (cancelled?)
        (let ((sig (catch #t (lambda () (chan-try-recv! cancel-chan #f)) (lambda args #f))))
          (and sig (not (eof-object? sig)) #t)
        ) ;let
      ) ;define
      (define (notify! ev)
        (chan-send! event-chan
          (list 'kimi_oauth_device_code
            provider
            (cadr ev)
            (caddr ev)
            (cadddr ev)
            (car (cddddr ev))
          ) ;list
          1000
        ) ;chan-send!
      ) ;define
      (let ((result
              (catch #t
                (lambda ()
                  (kimi-oauth-login notify!
                    cancelled?
                    provider
                    (list (cons "KIMI_CODE_OAUTH_HOST" oauth-host))
                  ) ;kimi-oauth-login
                ) ;lambda
                (lambda (tag . info)
                  (list 'error
                    tag
                    (if (and (pair? info) (string? (car info)))
                      (car info)
                      (catch-error->string tag info)
                    ) ;if
                  ) ;list
                ) ;lambda
              ) ;catch
            ) ;result
           ) ;
        (if (and (pair? result) (eq? (car result) 'error))
          (chan-send! event-chan
            (list 'kimi_oauth_done provider #f #f #f #f (cadr result) (caddr result))
            1000
          ) ;chan-send!
          (chan-send! event-chan
            (list 'kimi_oauth_done
              provider
              (pi-credential-access result)
              (pi-credential-refresh result)
              (pi-credential-expires result)
              (pi-credential-region result)
              #f
              #f
            ) ;list
            1000
          ) ;chan-send!
        ) ;if
      ) ;let
    ) ;define

    ;; device_code 事件：(kimi_oauth_device_code provider user-code uri interval expires)
    ;; 用真实 user_code/URL 替换占位组件
    (define (pi-app-handle-oauth-device-code! app ev)
      (%pi-app-active-selector-set! app
        (make-login-device-code (cadr ev)
          (list-ref ev 2)
          (list-ref ev 3)
          (lambda () (pi-app-close-login! app))
        ) ;make-login-device-code
      ) ;%pi-app-active-selector-set!
      (pi-app-render! app)
    ) ;define

    ;; done 事件：成功落盘 + reload_models + 上屏；失败上屏错误卡片；
    ;; 用户取消（kimi-oauth-cancelled）静默收尾
    (define (pi-app-handle-oauth-done! app ev)
      (let ((provider (cadr ev))
            (access (list-ref ev 2))
            (refresh (list-ref ev 3))
            (expires (list-ref ev 4))
            (region (list-ref ev 5))
            (err-tag (list-ref ev 6))
            (err-msg (list-ref ev 7))
           ) ;
        (%kimi-oauth-job-done! app provider access refresh expires region
          err-tag err-msg
        ) ;%kimi-oauth-job-done!
      ) ;let
    ) ;define

    (define (%kimi-oauth-job-done! app provider access refresh expires region
              err-tag err-msg
            ) ;%kimi-oauth-job-done!
      (cond
        (err-tag
          (unless (eq? err-tag 'kimi-oauth-cancelled)
            (pi-app-close-login! app)
            (container-add! (%pi-app-chat app)
              (make-tool-card "login"
                '()
                'error
                (string-append "Kimi Code OAuth login failed: " (or err-msg "unknown error"))
              ) ;make-tool-card
            ) ;container-add!
            (pi-app-scroll-bottom! app)
            (pi-app-render! app)
          ) ;unless
        ) ;err-tag
        (else
          (let* ((cfg-dir (gf-get-config-dir))
                 (saved-path (catch #t
                               (lambda () (pi-save-auth-oauth! provider access refresh expires region cfg-dir))
                               (lambda (tag . info) #f)
                             ) ;catch
                 ) ;saved-path
                ) ;
            (pi-app-close-login! app)
            (if saved-path
              (begin
                (when (pi-app-jobs-chan app)
                  (catch #t
                    (lambda ()
                      (chan-send! (pi-app-jobs-chan app)
                        (list 'reload_models (path->string (path cfg-dir)))
                        1000
                      ) ;chan-send!
                    ) ;lambda
                    (lambda args #f)
                  ) ;catch
                ) ;when
                (container-add! (%pi-app-chat app)
                  (make-assistant-card (string-append "Saved OAuth credential for " provider " to " saved-path)
                  ) ;make-assistant-card
                ) ;container-add!
              ) ;begin
              (container-add! (%pi-app-chat app)
                (make-tool-card "login"
                  '()
                  'error
                  (string-append "Failed to save OAuth credential for " provider)
                ) ;make-tool-card
              ) ;container-add!
            ) ;if
            (pi-app-scroll-bottom! app)
            (pi-app-render! app)
          ) ;let*
        ) ;else
      ) ;cond
    ) ;define

    (define (%split-args str)
      (filter (lambda (s) (not (string-null? s))) (string-split str " "))
    ) ;define

    (define (pi-app-submit-login! app text)
      (editor-set-text! (pi-app-editor app) "")
      (let* ((clean (string-trim-both text)))
        (if (string=? clean "/login")
          (pi-app-show-login-selector! app)
          (let* ((arg-str (string-trim-both (substring clean 6))) (args (%split-args arg-str)))
            (cond ((null? args) (pi-app-show-login-selector! app))
                  ((= (length args) 1) (pi-app-show-login-dialog! app (car args)))
                  (else (pi-app-save-login-key! app (car args) (cadr args)))
            ) ;cond
          ) ;let*
        ) ;if
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
