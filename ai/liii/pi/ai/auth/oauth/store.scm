;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OAuth 运行时凭据存储：与请求配置分离，按 provider 保存最新凭据。
;; store 自身可随不可变配置副本共享；刷新只替换 store 中的凭据，不修改
;; 配置对象，也不写 auth.json。
(define-library (liii pi ai auth oauth store)
  (import (scheme base) (liii list) (liii pi ai config credential))
  (export pi-make-oauth-store pi-oauth-store? pi-oauth-store-ref
    pi-oauth-store-set! pi-oauth-store-load! pi-oauth-store-remove!
    pi-oauth-store-clear!
  ) ;export
  (begin

    ;; 单元素 vector 保存凭据 alist。替换条目而非修改凭据 record。
    (define (pi-make-oauth-store . opt-credentials)
      (vector (if (pair? opt-credentials) (car opt-credentials) '()))
    ) ;define

    (define (pi-oauth-store? value)
      (and (vector? value) (= (vector-length value) 1))
    ) ;define

    (define (pi-oauth-store-ref store provider)
      (let ((p-str (if (symbol? provider) (symbol->string provider) provider)))
        (pi-find-credential p-str (vector-ref store 0))
      ) ;let
    ) ;define

    (define (pi-find-credential provider credentials)
      (find
        (lambda (cred)
          (and (pi-credential-oauth? cred)
            (equal? (pi-credential-provider cred) provider)
          ) ;and
        ) ;lambda
        credentials
      ) ;find
    ) ;define

    (define (pi-oauth-store-set! store cred)
      (let ((provider (pi-credential-provider cred)))
        (vector-set! store
          0
          (cons cred
            (filter
              (lambda (old) (not (equal? (pi-credential-provider old) provider)))
              (vector-ref store 0)
            ) ;filter
          ) ;cons
        ) ;vector-set!
      ) ;let
      cred
    ) ;define

    (define (pi-oauth-store-load! store credentials)
      (vector-set! store 0 (filter pi-credential-oauth? credentials))
      store
    ) ;define

    (define (pi-oauth-store-remove! store provider)
      (let ((p-str (if (symbol? provider) (symbol->string provider) provider)))
        (vector-set! store
          0
          (filter
            (lambda (cred) (not (equal? (pi-credential-provider cred) p-str)))
            (vector-ref store 0)
          ) ;filter
        ) ;vector-set!
      ) ;let
      #f
    ) ;define

    (define (pi-oauth-store-clear! store)
      (vector-set! store 0 '())
    ) ;define

  ) ;begin
) ;define-library
