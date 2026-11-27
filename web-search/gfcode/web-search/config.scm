;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode web-search config)
  (import (scheme base)
    (scheme process-context)
    (liii os)
    (liii string)
    (liii json)
    (liii path)
    (liii pi code core tools read)
    (liii pi code config)
    (liii pi ai auth)
    (liii pi ai template)
    (gfcode web-search proxy)
    (gfcode web-search base-url)
    (gfcode web-search types)
  ) ;import
  (export pi-resolve-google-api-key pi-resolve-search-base-url
    pi-resolve-search-proxy-url pi-resolve-search-proxy-alist
    pi-resolve-search-model-id pi-load-web-search-config
    pi-web-search-config-model pi-web-search-config-proxy
    pi-web-search-config-base-url pi-resolve-web-search-provider
    pi-resolve-deepseek-api-key pi-resolve-deepseek-search-base-url
    make-pi-web-search-config pi-web-search-config?
    pi-web-search-config-provider json->pi-web-search-config
    pi-web-search-config->json
  ) ;export
  (begin

    (define (pi-resolve-google-api-key config opt-key . opt-env)
      (let ((env (if (pair? opt-env) (car opt-env) #f)))
        (cond
         ((string? opt-key)
          (let ((trimmed (string-trim-both opt-key)))
            (if (string-null? trimmed) #f trimmed)
          ) ;let
         ) ;
         ((and (or (pi-config? config) (pair? config))
            (let ((p (%norm-provider (%cfg-ref config 'provider))))
              (or (not p) (equal? p "google"))
            ) ;let
            (let ((k (%cfg-ref config 'api-key)))
              (and (string? k) (not (string-null? (string-trim-both k))) k)
            ) ;let
          ) ;and
         ) ;
         ((%env-ref-str "GOOGLE_API_KEY" env))
         ((%env-ref-str "GEMINI_API_KEY" env))
         (else
           (catch #t
             (lambda ()
               (let* ((config-dir (%config-dir-from env))
                      (auth (if (pair? env) (pi-load-auth config-dir env) (pi-load-auth config-dir)))
                     ) ;
                 (if (pair? env)
                   (pi-resolve-provider-key "google" auth env)
                   (pi-resolve-provider-key "google" auth)
                 ) ;if
               ) ;let*
             ) ;lambda
             (lambda _ #f)
           ) ;catch
         ) ;else
        ) ;cond
      ) ;let
    ) ;define

    ;; 有效搜索 provider 专属缺省模型。
    ;; DeepSeek 缺省 deepseek-flash，Google 缺省 gemini-2.5-flash。
    (define (%default-search-model provider)
      (if (equal? provider "deepseek") "deepseek-flash" "gemini-2.5-flash")
    ) ;define

    ;; 解析联网搜索使用的模型标识。provider 为有效搜索后端（deepseek/google）。
    ;; 优先级：显式模型 > web-search.json 模型 > 匹配会话 provider 的 model-id > provider 缺省。
    ;; 会话 provider 与搜索 provider 不一致时跳过会话 model-id，避免跨 provider 串值。
    (define (pi-resolve-search-model-id config opt-model . opt-provider)
      (let* ((provider (%norm-provider (if (pair? opt-provider) (car opt-provider) #f)))
             (opt-model-str
               (if (string? opt-model)
                 (let ((trimmed (string-trim-both opt-model)))
                   (if (string-null? trimmed) #f trimmed)
                 ) ;let
                 #f
               ) ;if
             ) ;opt-model-str
             (cfg-provider (%norm-provider (%cfg-ref config 'provider)))
             (cfg-model (%cfg-ref config 'model-id))
             (same-provider? (and (string? provider) (string? cfg-provider) (equal? provider cfg-provider))
             ) ;same-provider?
            ) ;
        (cond (opt-model-str opt-model-str)
              ;; 未传入 provider（两参数调用）时保留原有行为：无条件使用会话 model-id
              ((and (not provider) (string? cfg-model)) cfg-model)
              ;; 传入 provider 后按 provider 匹配决定是否沿用会话 model-id
              ((and same-provider? (string? cfg-model)) cfg-model)
              (else (%default-search-model provider))
        ) ;cond
      ) ;let*
    ) ;define

    (define (%cfg-ref config key)
      (or (pi-cfg-ref config key #f)
        (and (pair? config) (pi-cfg-ref config (symbol->string key) #f))
      ) ;or
    ) ;define

    (define (%cfg-str config key)
      (let ((v (%cfg-ref config key)))
        (if
          (and (string? v) (not (string-null? (string-trim-both v))))
          v
          #f
        ) ;if
      ) ;let
    ) ;define

    (define (%env-ref-str name env)
      ;; env 是 alist 时只查 env（测试可控）；否则查真实环境变量
      (let ((v
              (if (pair? env)
                (let ((p (assoc name env)))
                  (and p (string? (cdr p)) (cdr p))
                ) ;let
                (get-environment-variable name)
              ) ;if
            ) ;v
           ) ;
        (and (string? v) (not (string-null? (string-trim-both v))) v)
      ) ;let
    ) ;define

    ;; JSON 配置文件目录：固定 ~/.gf/agent（不再回退 ~/.pi/agent）
    (define (%config-dir-from env)
      (catch #t
        (lambda ()
          (let ((env-dir (%env-ref-str "PI_CODING_AGENT_DIR" env)))
            (if env-dir (pi-abs-path env-dir) (gf-get-config-dir))
          ) ;let
        ) ;lambda
        (lambda _ #f)
      ) ;catch
    ) ;define

    (define (%read-json-file filepath)
      (and (or (string? filepath) (path? filepath))
        (path-exists? (path filepath))
        (catch #t
          (lambda () (string->json (path-read-text (path filepath))))
          (lambda _ #f)
        ) ;catch
      ) ;and
    ) ;define

    (define (%norm-provider s)
      (if (string? s)
        (list->string
          (map
            (lambda (c)
              (let ((n (char->integer c)))
                (if (and (>= n 65) (<= n 90)) (integer->char (+ n 32)) c)
              ) ;let
            ) ;lambda
            (string->list (string-trim-both s))
          ) ;map
        ) ;list->string
        s
      ) ;if
    ) ;define

    ;; 加载 <config-dir>/web-search.json（可用 PI_WEB_SEARCH_CONFIG 指定路径）：
    ;; {"provider": "deepseek|google", "model": "..."}
    ;; 存在时是全局覆盖：任何会话 provider/模型的 web_search 都用它。
    ;; 不存在或解析失败返回 #f。opt-env 提供时只查 opt-env（测试可控）。
    (define (pi-load-web-search-config . opt-env)
      (let* ((env (if (pair? opt-env) (car opt-env) #f))
             (explicit (%env-ref-str "PI_WEB_SEARCH_CONFIG" env))
             (config-dir (%config-dir-from env))
             (default-path
               (and config-dir
                 (catch #t (lambda () (path-join config-dir "web-search.json")) (lambda _ #f))
               ) ;and
             ) ;default-path
            ) ;
        (json->pi-web-search-config (or (%read-json-file explicit) (%read-json-file default-path))
        ) ;json->pi-web-search-config
      ) ;let*
    ) ;define

    (define (pi-web-search-config-model ws-config)
      (and (pi-web-search-config? ws-config)
        (pi-web-search-config-raw-model ws-config)
      ) ;and
    ) ;define

    ;; 决定 web_search 用哪个后端：只有 google/deepseek 两个后端，
    ;; 其余 provider 及缺省一律回退 deepseek；只有明确解析为 google 时
    ;; 继续使用 Gemini grounding。
    ;; 优先级：显式 opt > web-search.json（全局覆盖） > 环境变量 > config
    (define (pi-resolve-web-search-provider config opt-provider ws-config . opt-env)
      (let* ((env (if (pair? opt-env) (car opt-env) #f))
             (ws-provider (and (pi-web-search-config? ws-config)
                            (pi-web-search-config-provider ws-config)
                          ) ;and
             ) ;ws-provider
             (raw
               (cond
                ((and (string? opt-provider)
                   (not (string-null? (string-trim-both opt-provider)))
                 ) ;and
                 opt-provider
                ) ;
                (ws-provider)
                ((%cfg-str config 'web-search-provider))
                ((%env-ref-str "GF_PI_WEB_SEARCH_PROVIDER" env))
                ((%cfg-str config 'provider))
                (else "deepseek")
               ) ;cond
             ) ;raw
             (p (%norm-provider raw))
            ) ;
        (if (equal? p "google") "google" "deepseek")
      ) ;let*
    ) ;define

    (define (%deepseek-key-from-auth env)
      ;; 环境变量 + auth.json + deepseek 回退链（claude settings、~/.deepseek.json 等）
      (catch #t
        (lambda ()
          (if (pair? env)
            (pi-resolve-provider-key "deepseek" '() env)
            (pi-resolve-provider-key "deepseek" (pi-load-auth (%config-dir-from env)))
          ) ;if
        ) ;lambda
        (lambda _ #f)
      ) ;catch
    ) ;define

    (define (%config-wants-deepseek? config)
      (equal? (%norm-provider (%cfg-str config 'provider)) "deepseek")
    ) ;define

    (define (pi-resolve-deepseek-api-key config opt-key . opt-env)
      (let ((env (if (pair? opt-env) (car opt-env) #f)))
        (cond
          ;; 显式传入的 key：字符串但空白时直接失败，不再回退（与 Google 版一致）
          ((string? opt-key)
           (let ((trimmed (string-trim-both opt-key)))
             (if (string-null? trimmed) #f trimmed)
           ) ;let
          ) ;
          ;; config 的 api-key 仅当 provider 是 deepseek 时才可用
          ((and (%config-wants-deepseek? config) (%cfg-str config 'api-key))
           (%cfg-str config 'api-key)
          ) ;
          (else (%deepseek-key-from-auth env))
        ) ;cond
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
