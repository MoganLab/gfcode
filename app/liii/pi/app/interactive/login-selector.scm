;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 登录供应商选择器：展示各 provider 列表、配置状态（✓ configured / • not configured）、
;; 模糊搜索与选择流转；登记了订阅 OAuth 的 provider（如 kimi-coding）
;; 选中后进入二级选择「API Key / Kimi Code 订阅（OAuth）」。
(define-library (liii pi app interactive login-selector)
  (export make-login-selector login-selector? login-selector-cursor-position
    login-selector-method-mode?
  ) ;export
  (import (scheme base)
    (scheme process-context)
    (liii string)
    (liii list)
    (liii unicode)
    (liii path)
    (liii tui)
    (liii tui component)
    (liii pi ai auth)
    (liii pi ai config credential)
    (liii pi ai providers registry)
    (liii pi code config)
  ) ;import
  (begin

    (define %accent "\x1b;[35m")
    (define %muted "\x1b;[38;2;157;165;169m")
    (define %border "\x1b;[38;2;91;127;200m")
    (define %success "\x1b;[32m")
    (define %reset "\x1b;[0m")

    (define (%colored color text)
      (string-append color text %reset)
    ) ;define

    (define-record-type <login-selector-state>
      (%make-login-selector-state current providers config-dir on-select
        on-cancel on-select-method search list method-provider
      ) ;%make-login-selector-state
      login-selector-state?
      (current login-selector-state-current)
      (providers login-selector-state-providers)
      (config-dir login-selector-state-config-dir)
      (on-select login-selector-state-on-select)
      (on-cancel login-selector-state-on-cancel)
      (on-select-method login-selector-state-on-select-method)
      (search login-selector-state-search login-selector-state-search-set!)
      (list login-selector-state-list login-selector-state-list-set!)
      ;; 非 #f 时处于二级登录方式选择态，值为目标 provider
      (method-provider login-selector-state-method-provider
        login-selector-state-method-provider-set!
      ) ;method-provider
    ) ;define-record-type

    (define (%state comp)
      (let ((data (component-data comp)))
        (and (pair? data) (eq? (car data) 'login-selector) (cadr data))
      ) ;let
    ) ;define

    (define (login-selector? obj)
      (and (component? obj) (login-selector-state? (%state obj)))
    ) ;define

    (define (login-selector-list comp)
      (login-selector-state-list (%state comp))
    ) ;define

    (define (login-selector-search comp)
      (login-selector-state-search (%state comp))
    ) ;define

    (define (login-selector-cursor-position comp)
      (let ((search (login-selector-search comp)))
        (list 6 (+ 2 (editor-display-col search)))
      ) ;let
    ) ;define

    (define (login-selector-method-mode? comp)
      (and (login-selector-state-method-provider (%state comp)) #t)
    ) ;define

    (define (%non-empty-str? v)
      (and (string? v) (not (string-null? (string-trim-both v))))
    ) ;define

    (define (%provider-has-env-key? provider)
      (any (lambda (env-name) (%non-empty-str? (get-environment-variable env-name)))
        (pi-provider-env-keys provider)
      ) ;any
    ) ;define

    (define (%provider-status provider config-dir)
      (let* ((creds (catch #t (lambda () (pi-load-auth config-dir)) (lambda args '())))
             (cred
               (find
                 (lambda (c)
                   (and (pi-credential? c) (equal? (pi-credential-provider c) provider))
                 ) ;lambda
                 creds
               ) ;find
             ) ;cred
             (has-auth?
               (and cred
                 (or (%non-empty-str? (pi-credential-key cred))
                   (%non-empty-str? (pi-credential-access cred))
                 ) ;or
               ) ;and
             ) ;has-auth?
            ) ;
        (if (or has-auth? (%provider-has-env-key? provider))
          "✓ configured"
          "• not configured"
        ) ;if
      ) ;let*
    ) ;define

    (define (%provider-items state)
      (let ((cfg-dir (login-selector-state-config-dir state)))
        (map
          (lambda (provider)
            (let* ((status (%provider-status provider cfg-dir))
                   (configured? (string-starts? status "✓"))
                  ) ;
              (list (cons 'value provider)
                (cons 'label provider)
                (cons 'description
                  (if configured? (%colored %success status) (%colored %muted status))
                ) ;cons
              ) ;list
            ) ;let*
          ) ;lambda
          (login-selector-state-providers state)
        ) ;map
      ) ;let
    ) ;define

    ;; 二级登录方式选择：登记了订阅 OAuth 的 provider 展示
    ;; 「API Key / Kimi Code 订阅（OAuth）」两项（1402 §5.4）
    (define (%method-items state)
      (list (list (cons 'value "api_key")
              (cons 'label "API Key")
              (cons 'description (%colored %muted "Paste an API key from the console"))
            ) ;list
        (list (cons 'value "oauth")
          (cons 'label "Kimi Code (OAuth)")
          (cons 'description (%colored %muted "Sign in with your Kimi Code subscription"))
        ) ;list
      ) ;list
    ) ;define

    (define (%enter-method-mode! state provider)
      (login-selector-state-method-provider-set! state provider)
      (login-selector-state-list-set! state
        (%build-list state (%method-items state) "api_key")
      ) ;login-selector-state-list-set!
    ) ;define

    (define (%leave-method-mode! state)
      (login-selector-state-method-provider-set! state #f)
      (%refresh-list! state)
    ) ;define

    (define (%build-list state items preselect)
      (let ((lst
              (make-select-list items
                (max 1 (min 8 (length items)))
                :min-primary-column-width 16
                :max-primary-column-width 32
                :selected-text    (lambda (text) (%colored %accent text))
                :description-text (lambda (text) text)
                :scroll-text      (lambda (text) (%colored %muted text))
                :no-match-text    (lambda (text) (%colored %muted text))
                :on-select
                (lambda (item)
                  (let ((value (cdr (assoc 'value item))))
                    (if (login-selector-state-method-provider state)
                     ((login-selector-state-on-select-method state)
                      (login-selector-state-method-provider state)
                      value
                     ) ;
                     (if (pi-provider-oauth value)
                       (%enter-method-mode! state value)
                       ((login-selector-state-on-select state) value)
                     ) ;if
                    ) ;if
                  ) ;let
                ) ;lambda
                :on-cancel
                (lambda ()
                  (if (login-selector-state-method-provider state)
                    (%leave-method-mode! state)
                    ((login-selector-state-on-cancel state))
                  ) ;if
                ) ;lambda
              ) ;make-select-list
            ) ;lst
            (index
              (list-index
                (lambda (item) (equal? (cdr (assoc 'value item)) preselect))
                items
              ) ;list-index
            ) ;index
           ) ;
        (when index
          (select-list-set-selected-index! lst index)
        ) ;when
        lst
      ) ;let
    ) ;define

    (define (%refresh-list! state)
      (let* ((old-list (login-selector-state-list state))
             (selected (and old-list (select-list-selected-item old-list)))
             (preselect (and selected (cdr (assoc 'value selected))))
             (query (editor-text (login-selector-state-search state)))
             (filtered
               (fuzzy-filter (%provider-items state)
                 query
                 (lambda (item) (cdr (assoc 'value item)))
               ) ;fuzzy-filter
             ) ;filtered
            ) ;
        (login-selector-state-list-set! state (%build-list state filtered preselect))
      ) ;let*
    ) ;define

    (define (%render comp width)
      (let* ((state (%state comp))
             (border (%colored %border (utf8-make-string (max 1 width) #\─)))
             (search (login-selector-state-search state))
             (search-lines (component-render search (max 1 (- width 2))))
             (search-line (if (pair? search-lines) (string-append "> " (car search-lines)) "> ")
             ) ;search-line
             (method-provider (login-selector-state-method-provider state))
             (hint (%colored %muted
                     (if method-provider
                       "  enter to select · esc to go back"
                       "  enter to select · esc to cancel"
                     ) ;if
                   ) ;%colored
             ) ;hint
            ) ;
        (if method-provider
          (append (list border
                    ""
                    (string-append "Login to " method-provider)
                    ""
                    "Select a login method"
                    ""
                  ) ;list
            (component-render (login-selector-state-list state) width)
            (list "" hint)
          ) ;append
          (append (list border "" "Login Provider" ""
                    "Select a provider to configure authentication" ""
                    search-line ""
                  ) ;list
            (component-render (login-selector-state-list state) width)
            (list "" hint)
          ) ;append
        ) ;if
      ) ;let*
    ) ;define

    (define (%handle-input comp key)
      (let ((state (%state comp)))
        (cond
         ((or (memq key '(up down enter escape ctrl-c))
            (login-selector-state-method-provider state)
          ) ;or
          (component-handle-input (login-selector-state-list state) key)
         ) ;
         (else (component-handle-input (login-selector-state-search state) key))
        ) ;cond
      ) ;let
    ) ;define

    (define* (make-login-selector on-select
               on-cancel
               (current #f)
               (config-dir #f)
               (providers #f)
               (on-select-method #f)
             ) ;make-login-selector
      (let* ((actual-cfg-dir (or config-dir (gf-get-config-dir)))
             (actual-providers (or providers PI_SUPPORTED_PROVIDERS))
             ;; 未注入二级回调时退化：两种方式都走 on-select（旧行为可用）
             (actual-on-method (or on-select-method (lambda (p m) (on-select p))))
             (state (%make-login-selector-state current actual-providers
                      actual-cfg-dir on-select on-cancel actual-on-method #f #f
                      #f
                    ) ;%make-login-selector-state
             ) ;state
             (search (make-text-input ""
                       :multiline #f
                       :focused   #t
                       :on-change (lambda (ed text) (%refresh-list! state))
                     ) ;make-text-input
             ) ;search
             (comp (make-component :render %render :handle-input %handle-input))
            ) ;
        (login-selector-state-search-set! state search)
        (login-selector-state-list-set! state
          (%build-list state (%provider-items state) current)
        ) ;login-selector-state-list-set!
        (component-data-set! comp (list 'login-selector state))
        comp
      ) ;let*
    ) ;define*
  ) ;begin
) ;define-library
