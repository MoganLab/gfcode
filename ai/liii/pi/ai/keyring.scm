;;
;; Ported from @earendil-works/pi-coding-agent (https://github.com/earendil-works/pi)
;; Original work Copyright (c) 2025 Mario Ortiz Manero / Earendil Works
;; Goldfish Scheme port Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 通用 API key 钩子接口：核心请求路径只认识 config 中的
;; request-key / rotate-key 过程钩子，密钥池策略由
;; 扩展经 config augmenter 注入，核心不依赖任何具体实现库。

(define-library (liii pi ai keyring)
  (import (scheme base) (liii pi ai config runtime))
  (export pi-request-api-key
    pi-key-rotation?
    pi-rotate-api-key!
    ;; 1404：oauth 凭据收到 401 后强制刷新重试一次
    pi-oauth-refresh-enabled?
    pi-refresh-oauth-key!
  ) ;export

  (begin
    (define (%config-ref config key)
      (pi-cfg-ref config key)
    ) ;define

    ;; 每次请求开始时取本次使用的 key：
    ;; 无钩子时回退 config 的 api-key（auth.json 单 key 路径）。
    (define (pi-request-api-key config)
      (let ((hook (%config-ref config 'request-key))
            (oauth-hook (%config-ref config 'request-oauth-key))
           ) ;
        (if (procedure? hook)
          (hook config)
          (if (procedure? oauth-hook) (oauth-hook config) (%config-ref config 'api-key))
        ) ;if
      ) ;let
    ) ;define

    ;; 是否启用 429/403 自动换 key：由扩展是否注入 rotate-key 钩子决定。
    (define (pi-key-rotation? config)
      (procedure? (%config-ref config 'rotate-key))
    ) ;define

    ;; 429/403 后请求换 key：
    ;; 钩子返回下一可用 key 字符串或 'exhausted（池耗尽）；
    ;; 无钩子时返回 #f（调用方走既有重试/报错路径）；
    ;; 可选 port 仅在提供时作为第 4 参转发（兼容 3 参钩子）。
    (define* (pi-rotate-api-key! config current-key status (opt-port #f))
      (let ((hook (%config-ref config 'rotate-key)))
        (cond ((not (procedure? hook)) #f)
              (opt-port (hook config current-key status opt-port))
              (else (hook config current-key status))
        ) ;cond
      ) ;let
    ) ;define*

    ;; 1404：是否启用 401 后 oauth 强制刷新：由配置是否注入
    ;; refresh-oauth-key 钩子决定（仅 oauth provider 注入）。
    (define (pi-oauth-refresh-enabled? config)
      (procedure? (%config-ref config 'refresh-oauth-key))
    ) ;define

    ;; 1404：401 后强制刷新 oauth 凭据：
    ;; 钩子签名 (lambda (config current-key) ...) 返回
    ;;   string?  - 新 access token，调用方用其重试一次
    ;;   'unauthorized - refresh 失败（401/403/invalid_grant），凭据已清除，需重 /login
    ;;   #f       - 非 oauth/无凭据/不适用，调用方按现状 401 报错
    ;; 无钩子时返回 #f（调用方走既有 401 报错路径）。
    (define (pi-refresh-oauth-key! config current-key)
      (let ((hook (%config-ref config 'refresh-oauth-key)))
        (if (procedure? hook) (hook config current-key) #f)
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
