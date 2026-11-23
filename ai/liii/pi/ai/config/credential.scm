;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi ai config credential)
  (import (scheme base) (liii base) (liii error))
  (export pi-credential pi-credential? pi-credential-provider pi-credential-key
    pi-credential-type pi-credential->json
    pi-credential-access pi-credential-refresh pi-credential-expires
    pi-credential-region pi-credential-oauth?
  ) ;export
  (begin

    ;; 凭据记录：type 为 "api_key"（默认，key 承载 API Key）或 "oauth"
    ;; （access/refresh/expires 承载 OAuth token，expires 为毫秒 epoch；
    ;; region 记录登录时的 OAuth host 覆盖值，默认 host 不写 region，
    ;; 对应上游 pi 的 ApiKeyCredential / OAuthCredential，1402 §5.1）
    (define*-record-type <pi-credential>
      (pi-credential provider key (type "api_key")
        (access #f) (refresh #f) (expires #f) (region #f))
      pi-credential?
      (provider pi-credential-provider)
      (key pi-credential-key)
      (type pi-credential-type)
      (access pi-credential-access)
      (refresh pi-credential-refresh)
      (expires pi-credential-expires)
      (region pi-credential-region)
    ) ;define*-record-type

    (define (pi-credential-oauth? c)
      (and (pi-credential? c) (equal? (pi-credential-type c) "oauth"))
    ) ;define

    (define (pi-credential->json c)
      (unless (pi-credential? c)
        (type-error "pi-credential->json: expected pi-credential" c)
      ) ;unless
      (if (pi-credential-oauth? c)
        ;; oauth 条目形状与 pi 的 auth.json OAuth 条目一致；region 仅在
        ;; 有值（env 覆盖过 host）时落盘
        (append (list (cons "provider" (pi-credential-provider c))
                  (cons "type" "oauth")
                  (cons "access" (pi-credential-access c))
                  (cons "refresh" (pi-credential-refresh c))
                  (cons "expires" (pi-credential-expires c))
                ) ;list
          (if (pi-credential-region c)
            (list (cons "region" (pi-credential-region c)))
            '()
          ) ;if
        ) ;append
        (list (cons "provider" (pi-credential-provider c))
          (cons "type" (pi-credential-type c))
          (cons "key" (pi-credential-key c))
        ) ;list
      ) ;if
    ) ;define

  ) ;begin
) ;define-library