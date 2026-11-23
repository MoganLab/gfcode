;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OAuth 凭据在独立的内存 store 中维护，请求配置保持副本语义。
;; 初始 sync 从 auth.json 载入 store；每次请求动态读取 access token，
;; 过期或收到 401 时刷新并仅更新内存，不写 auth.json。
(define-library (liii pi code config oauth-hook)
  (import (scheme base)
    (scheme process-context)
    (liii path)
    (liii pi ai auth)
    (liii pi ai config credential)
    (liii pi ai auth oauth resolve)
    (liii pi ai auth oauth store)
    (liii pi ai config runtime)
    (liii pi ai time)
  ) ;import
  (export pi-make-refresh-oauth-hook pi-sync-oauth-refresh-hook
    pi-make-request-oauth-key-hook pi-oauth-store-for-config
  ) ;export
  (begin

    (define (pi-oauth-store-for-config cfg captured-env captured-dir)
      (or (pi-cfg-ref cfg 'oauth-store #f)
        (pi-make-oauth-store
          (if (pair? captured-env)
            (pi-load-auth captured-dir captured-env)
            (pi-load-auth captured-dir)
          ) ;if
        ) ;or
      ) ;let
    ) ;define

    (define (%refresh! store cred captured-env)
      (let ((next (pi-force-refresh-oauth-credential-key cred
                    captured-env
                    (lambda (c) (pi-oauth-store-set! store c))
                    (lambda (p) (pi-oauth-store-remove! store p))
                  ) ;pi-force-refresh-oauth-credential-key
            ) ;next
           ) ;
        next
      ) ;let
    ) ;define

    ;; 每次新请求解析 key。配置副本可共享 store，但 store 不依赖配置身份；
    ;; 未过期直接返回 access，过期时透明刷新并替换内存中的完整凭据。
    (define (pi-make-request-oauth-key-hook captured-env captured-dir)
      (lambda (cfg)
        (let* ((p (pi-cfg-ref cfg 'provider #f))
               (store (pi-oauth-store-for-config cfg captured-env captured-dir))
               (cred (and p (pi-oauth-store-ref store p)))
              ) ;
          (and cred
            (let ((access (pi-credential-access cred))
                  (expires (pi-credential-expires cred))
                 ) ;
              (if (and access expires (> expires (+ (pi-current-time-millis) 60000)))
                access
                (%refresh! store cred captured-env)
              ) ;if
            ) ;let
          ) ;and
        ) ;let*
      ) ;lambda
    ) ;define

    ;; 401 后强制刷新：只更新内存 store，不修改请求配置，也不落盘。
    (define (pi-make-refresh-oauth-hook captured-env captured-dir)
      (lambda (cfg current-key)
        (let* ((p (pi-cfg-ref cfg 'provider #f))
               (store (pi-oauth-store-for-config cfg captured-env captured-dir))
               (cred (and p (pi-oauth-store-ref store p)))
              ) ;
          (and cred (%refresh! store cred captured-env))
        ) ;let*
      ) ;lambda
    ) ;define

    ;; 按 cfg 当前 provider 同步 request-oauth-key / refresh-oauth-key。
    ;; 初始无 store 时从 auth.json 初始化；切模复制配置会保留同一 store，
    ;; /login 后 reload 移除旧 store 并重新载入登录后的 auth.json。
    (define (pi-sync-oauth-refresh-hook cfg . opt-env)
      (let* ((env (if (pair? opt-env) (car opt-env) (get-environment-variables)))
             (dir (or (pi-cfg-ref cfg 'config-dir) (pi-cfg-ref cfg 'agent-dir)))
             (dir-str (if (path? dir) (path->string dir) dir))
             (provider (pi-cfg-ref cfg 'provider #f))
             (store (pi-oauth-store-for-config cfg env dir-str))
             (cred (and provider (pi-oauth-store-ref store provider)))
            ) ;
        (pi-cfg-merge cfg
          (list (cons 'oauth-store store)
            (cons 'request-oauth-key
              (if cred (pi-make-request-oauth-key-hook env dir-str) #f)
            ) ;cons
            (cons 'refresh-oauth-key
              (if cred (pi-make-refresh-oauth-hook env dir-str) #f)
            ) ;cons
          ) ;list
        ) ;pi-cfg-merge
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
