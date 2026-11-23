;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi ai auth)
  (import (scheme base)
    (scheme process-context)
    (liii string)
    (liii path)
    (liii json)
    (liii list)
    (liii error)
    (liii os)
    (liii pi ai template)

    (liii pi ai config credential)
    (liii pi ai auth oauth kimi-coding-oauth)
    (liii pi ai auth oauth resolve)
    (liii pi ai auth storage)
  ) ;import
  (export pi-load-auth
    pi-resolve-provider-key
    pi-save-auth-key
    pi-save-auth-oauth!
    pi-remove-auth-provider!
    ;; go worker 会话重求值调用链：刷新/落盘路径上的助手须导出
    %resolve-oauth-credential-key
  ) ;export
  (begin

    (define (%dict-ref obj key default-val)
      (if (not (pair? obj))
        default-val
        (let* ((str-key (if (symbol? key) (symbol->string key) key))
               (sym-key (if (string? key) (string->symbol key) key))
               (pair (or (assoc str-key obj) (assoc sym-key obj)))
              ) ;
          (if pair (cdr pair) default-val)
        ) ;let*
      ) ;if
    ) ;define

    (define (%read-json-file filepath)
      (and (path-exists? (path filepath))
        (catch #t
          (lambda () (string->json (path-read-text (path filepath))))
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    (define (%parse-credential-item key val opt-env)
      (and (pair? val)
        (let ((p-str (if (symbol? key) (symbol->string key) key))
              (type (%dict-ref val "type" #f))
             ) ;
          (cond
           ((equal? type "api_key")
            (let ((raw-key (%dict-ref val "key" #f)))
              (and (string? raw-key)
                (let ((resolved (if (pair? opt-env)
                                  (pi-resolve-config-value raw-key (car opt-env))
                                  (pi-resolve-config-value raw-key)
                                ) ;if
                      ) ;resolved
                     ) ;
                  (and resolved (pi-credential p-str resolved "api_key"))
                ) ;let
              ) ;and
            ) ;let
           ) ;
           ((equal? type "oauth")
            ;; oauth 条目：access/refresh 为非空字符串，expires 为毫秒 epoch；
            ;; region 可选（登录时的 OAuth host 覆盖值）
            (let ((access (%dict-ref val "access" #f))
                  (refresh (%dict-ref val "refresh" #f))
                  (expires (%dict-ref val "expires" #f))
                  (region (%dict-ref val "region" #f))
                 ) ;
              (and (string? access)
                (not (string-null? access))
                (string? refresh)
                (not (string-null? refresh))
                (number? expires)
                (pi-credential p-str
                  #f
                  "oauth"
                  access
                  refresh
                  expires
                  (and (string? region) (not (string-null? region)) region)
                ) ;pi-credential
              ) ;and
            ) ;let
           ) ;
           (else #f)
          ) ;cond
        ) ;let
      ) ;and
    ) ;define

    (define (pi-load-auth config-dir . opt-env)
      (let* ((filepath (path-join config-dir "auth.json"))
             (data (%read-json-file filepath))
            ) ;
        (if (not (pair? data))
          '()
          (filter (lambda (credential) credential)
            (map
              (lambda (entry)
                ;; 防御空对象 {}（string->json 产出 '(()))：无条目可解析
                (and (pair? entry) (%parse-credential-item (car entry) (cdr entry) opt-env))
              ) ;lambda
              data
            ) ;map
          ) ;filter
        ) ;if
      ) ;let*
    ) ;define

    (define (%find-claude-deepseek-token home)
      (if (string-null? home)
        #f
        (let* ((f (path->string (path-join (path home) (path ".claude") (path "settings.json.deepseek"))
                  ) ;path->string
               ) ;f
               (data (%read-json-file f))
              ) ;
          (and data
            (let ((e (%dict-ref data "env" #f)))
              (and (pair? e)
                (let ((tok (%dict-ref e "ANTHROPIC_AUTH_TOKEN" #f)))
                  (and (string? tok) (not (string-null? tok)) tok)
                ) ;let
              ) ;and
            ) ;let
          ) ;and
        ) ;let*
      ) ;if
    ) ;define

    (define (%find-dot-deepseek-key home)
      (if (string-null? home)
        #f
        (let* ((f (path->string (path-join (path home) (path ".deepseek.json"))))
               (data (%read-json-file f))
              ) ;
          (and data
            (let ((k (%dict-ref data "api_key" #f)))
              (and (string? k) (not (string-null? k)) k)
            ) ;let
          ) ;and
        ) ;let*
      ) ;if
    ) ;define

    (define (%env-var-non-empty name opt-env)
      (let ((v (lookup-env-var name opt-env)))
        (and (string? v) (not (string-null? (string-trim-both v))) v)
      ) ;let
    ) ;define

    (define (%resolve-deepseek-fallback opt-env)
      (let* ((home (or (lookup-env-var "HOME" opt-env) ""))
             (claude-k (%find-claude-deepseek-token home))
            ) ;
        (if claude-k
          claude-k
          (let ((ds-k (%find-dot-deepseek-key home)))
            (if ds-k ds-k (%env-var-non-empty "ANTHROPIC_AUTH_TOKEN" opt-env))
          ) ;let
        ) ;if
      ) ;let*
    ) ;define

    (define (%resolve-provider-env-key p-str opt-env)
      (cond ((string=? p-str "google") (%env-var-non-empty "GEMINI_API_KEY" opt-env))
            ((string=? p-str "kimi-coding") (%env-var-non-empty "KIMI_API_KEY" opt-env))
            ((string=? p-str "anthropic")
             (or (%env-var-non-empty "ANTHROPIC_API_KEY" opt-env)
               (%env-var-non-empty "ANTHROPIC_AUTH_TOKEN" opt-env)
             ) ;or
            ) ;
            ((string=? p-str "glm")
             (or (%env-var-non-empty "ANTHROPIC_AUTH_TOKEN" opt-env)
               (%env-var-non-empty "GLM_API_KEY" opt-env)
               (%env-var-non-empty "ANTHROPIC_API_KEY" opt-env)
             ) ;or
            ) ;
            ((string=? p-str "deepseek") (%env-var-non-empty "DEEPSEEK_API_KEY" opt-env))
            ((string=? p-str "ollama") (%env-var-non-empty "OLLAMA_API_KEY" opt-env))
            ((string=? p-str "minimax-cn")
             (or (%env-var-non-empty "MINIMAX_CN_API_KEY" opt-env)
               (%env-var-non-empty "MINIMAX_API_KEY" opt-env)
             ) ;or
            ) ;
            ((or (string=? p-str "zai-coding-cn") (string=? p-str "zai"))
             (or (%env-var-non-empty "ZAI_CODING_CN_API_KEY" opt-env)
               (%env-var-non-empty "ZAI_API_KEY" opt-env)
               (%env-var-non-empty "GLM_API_KEY" opt-env)
               (%env-var-non-empty "ZHIPU_API_KEY" opt-env)
             ) ;or
            ) ;
            ((or (string=? p-str "opencode") (string=? p-str "opencode-go"))
             (or (%env-var-non-empty "OPENCODE_API_KEY" opt-env)
               (%env-var-non-empty "OPENCODE_GO_API_KEY" opt-env)
             ) ;or
            ) ;
            ((string=? p-str "qwen-token-plan-cn")
             (or (%env-var-non-empty "QWEN_TOKEN_PLAN_TEAM_CN_API_KEY" opt-env)
               (%env-var-non-empty "QWEN_TOKEN_PLAN_CN_API_KEY" opt-env)
             ) ;or
            ) ;
            (else #f)
      ) ;cond
    ) ;define

    (define (%provider-alias p-str)
      (cond ((string=? p-str "zai-coding-cn") "zai")
            ((string=? p-str "zai") "zai-coding-cn")
            ((string=? p-str "opencode") "opencode-go")
            ((string=? p-str "opencode-go") "opencode")
            (else #f)
      ) ;cond
    ) ;define

    (define (%non-empty-auth-key val)
      (and (string? val) (not (string-null? (string-trim-both val))) val)
    ) ;define

    (define (%find-auth-key target auth-list)
      (and target
        (let ((sym-target (string->symbol target)))
          (let loop
            ((xs auth-list))
            (if (null? xs)
              #f
              (let ((item (car xs)))
                (cond
                 ((pi-credential? item)
                  (if (or (equal? (pi-credential-provider item) target)
                        (equal? (pi-credential-provider item) sym-target)
                      ) ;or
                    (%non-empty-auth-key (pi-credential-key item))
                    (loop (cdr xs))
                  ) ;if
                 ) ;
                 ((pair? item)
                  (if (or (equal? (car item) target) (equal? (car item) sym-target))
                    (%non-empty-auth-key (cdr item))
                    (loop (cdr xs))
                  ) ;if
                 ) ;
                 (else (loop (cdr xs)))
                ) ;cond
              ) ;let
            ) ;if
          ) ;let
        ) ;let
      ) ;and
    ) ;define

    ;; 配置解析只返回凭据快照中的 access，不在启动/切模时联网刷新。
    ;; 请求前的 request-oauth-key 钩子统一检查 expires 并更新内存 store。
    (define (%resolve-oauth-credential-key cred opt-env opt-config-dir)
      (pi-credential-access cred)
    ) ;define

    ;; 解析服务商生效密钥。opt 尾参兼容旧调用形态：
    ;;   (provider auth-alist)
    ;;   (provider auth-alist env)
    ;;   (provider auth-alist env config-dir)
    ;; oauth 仅返回内存快照中的 access；请求前由动态钩子按需刷新。
    ;; env API Key 优先于一切 auth 条目。
    (define (pi-resolve-provider-key provider auth-alist . opt)
      (let* ((p-str (if (symbol? provider) (symbol->string provider) provider))
             (opt-env
               (if (and (pair? opt) (pair? (car opt))) opt '())
             ) ;opt-env
             (opt-config-dir
               (if (and (pair? opt) (pair? (cdr opt))) (cdr opt) '())
             ) ;opt-config-dir
             (env-k (%resolve-provider-env-key p-str opt-env))
            ) ;
        (if env-k
          env-k
          (let ((alias (%provider-alias p-str)))
            (or (%find-auth-key p-str auth-alist)
              (%find-auth-key alias auth-alist)
              (let ((oauth-cred (or (pi-find-oauth-credential p-str auth-alist)
                                  (pi-find-oauth-credential alias auth-alist)
                                ) ;or
                    ) ;oauth-cred
                   ) ;
                (and oauth-cred
                  (%resolve-oauth-credential-key oauth-cred opt-env opt-config-dir)
                ) ;and
              ) ;let
              (cond ((string=? p-str "deepseek") (%resolve-deepseek-fallback opt-env))
                    ((string=? p-str "ollama") "ollama")
                    (else #f)
              ) ;cond
            ) ;or
          ) ;let
        ) ;if
      ) ;let*
    ) ;define

    (define (%normalize-provider-key provider)
      (pi-auth-normalize-provider "pi-save-auth-key" provider)
    ) ;define

    (define (%normalize-auth-key key)
      (pi-auth-normalize-secret "pi-save-auth-key" "key" key)
    ) ;define

    (define (%update-auth-alist alist p-str key)
      (pi-auth-replace-entry alist
        p-str
        (list (cons "type" "api_key") (cons "key" key))
      ) ;pi-auth-replace-entry
    ) ;define

    (define (pi-save-auth-key provider key . opt-config-dir)
      (let* ((p-str (%normalize-provider-key provider))
             (k-str (%normalize-auth-key key))
             (dir-path (pi-auth-dir-path opt-config-dir))
             (auth-file-str (path->string (path-join dir-path "auth.json")))
             (existing (or (%read-json-file auth-file-str) '()))
             (existing-alist (if (pair? existing) existing '()))
             (updated (%update-auth-alist existing-alist p-str k-str))
            ) ;
        (pi-auth-write-json! dir-path updated)
      ) ;let*
    ) ;define

    ;; 保存 oauth 凭据：{provider: {type:"oauth", access, refresh, expires
    ;; [, region]}}，复用 pi-save-auth-key 的原子写策略（tmp + rename +
    ;; chmod 0600）；region 为 #f 时不写（默认 host 不落 region，1402 §7）
    (define (pi-save-auth-oauth! provider access refresh expires region . opt-config-dir)
      (let* ((p-str (pi-auth-normalize-provider "pi-save-auth-oauth!" provider))
             (a-str (pi-auth-normalize-secret "pi-save-auth-oauth!" "access" access))
             (r-str (pi-auth-normalize-secret "pi-save-auth-oauth!" "refresh" refresh))
             (dir-path (pi-auth-dir-path opt-config-dir))
             (auth-file-str (path->string (path-join dir-path "auth.json")))
             (existing (or (%read-json-file auth-file-str) '()))
             (existing-alist (if (pair? existing) existing '()))
            ) ;
        (unless (number? expires)
          (type-error "pi-save-auth-oauth!: expires must be a number")
        ) ;unless
        (unless (> expires 0)
          (value-error "pi-save-auth-oauth!: expires must be a positive number")
        ) ;unless
        (unless
          (or (not region) (and (string? region) (not (string-null? region))))
          (type-error "pi-save-auth-oauth!: region must be a non-empty string or #f")
        ) ;unless
        (pi-auth-write-json! dir-path
          (pi-auth-replace-entry existing-alist
            p-str
            (append (list (cons "type" "oauth")
                      (cons "access" a-str)
                      (cons "refresh" r-str)
                      (cons "expires" expires)
                    ) ;list
              (if region (list (cons "region" region)) '())
            ) ;append
          ) ;pi-auth-replace-entry
        ) ;pi-auth-write-json!
      ) ;let*
    ) ;define

    ;; 清除某 provider 的凭据条目（oauth 刷新失败 401/403/invalid_grant 时
    ;; 调用，对应 pi Models 的凭据清除）；文件不存在时直接返回路径
    (define (pi-remove-auth-provider! provider . opt-config-dir)
      (let* ((p-str (pi-auth-normalize-provider "pi-remove-auth-provider!" provider))
             (dir-path (pi-auth-dir-path opt-config-dir))
             (auth-file-str (path->string (path-join dir-path "auth.json")))
             (existing (%read-json-file auth-file-str))
            ) ;
        (if (pair? existing)
          (pi-auth-write-json! dir-path
            (filter
              (lambda (entry)
                (not
                  (string=? (if (symbol? (car entry)) (symbol->string (car entry)) (car entry))
                    p-str
                  ) ;string=?
                ) ;not
              ) ;lambda
              existing
            ) ;filter
          ) ;pi-auth-write-json!
          auth-file-str
        ) ;if
      ) ;let*
    ) ;define
  ) ;begin
) ;define-library
