;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OAuth 凭据在独立的内存 store 中维护，请求配置保持副本语义。
;; access token 仅存在于内存（短命，不值得落盘）；refresh token 轮换后
;; 连同 expires 一起写回 auth.json，确保重启后能用新 refresh token 继续刷新。
;; invalid_grant 时同时清除内存与 auth.json 条目（对应原 OAuth2 语义）。
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
        (pi-make-oauth-store (if (pair? captured-env)
                               (pi-load-auth captured-dir captured-env)
                               (pi-load-auth captured-dir)
                             ) ;if
        ) ;pi-make-oauth-store
      ) ;or
    ) ;define

    ;; 刷新成功时把 refresh/expires 落盘（保留盘上旧 access，不写入新 access：
    ;; access 短命不值得持久化，重启后由 request-oauth-key 检测到过期再刷新）。
    ;; 落盘失败仅记日志，不阻断本次请求。
    (define (%persist-refresh! captured-dir new-cred)
      (let* ((dir captured-dir)
             (provider (pi-credential-provider new-cred))
             (disk-cred (pi-find-oauth-credential provider (pi-load-auth dir)))
             (disk-access (if disk-cred
                            (pi-credential-access disk-cred)
                            (pi-credential-access new-cred)
                          ) ;if
             ) ;disk-access
            ) ;
        (pi-save-auth-oauth! provider
          disk-access
          (pi-credential-refresh new-cred)
          (pi-credential-expires new-cred)
          (pi-credential-region new-cred)
          dir
        ) ;pi-save-auth-oauth!
      ) ;let*
    ) ;define

    (define (%refresh! store cred captured-env captured-dir)
      ;; resolve 的 opt-env 约定为 (env-alist)，不能直接把 env-alist 传入，
      ;; 否则下游会把首个环境变量 pair 当作完整 alist 交给 assoc。
      ;; save! 更新内存 store 并落盘 refresh/expires；remove! 清内存与盘上条目。
      (let ((next (pi-force-refresh-oauth-credential-key cred
                    (if (pair? captured-env) (list captured-env) '())
                    (lambda (c)
                      (pi-oauth-store-set! store c)
                      (%persist-refresh! captured-dir c)
                    ) ;lambda
                    (lambda (p)
                      (pi-oauth-store-remove! store p)
                      (pi-remove-auth-provider! p captured-dir)
                    ) ;lambda
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
            (let ((access (pi-credential-access cred)) (expires (pi-credential-expires cred)))
              (if
                (and access expires (> expires (+ (pi-current-time-millis) 60000)))
                access
                (%refresh! store cred captured-env captured-dir)
              ) ;if
            ) ;let
          ) ;and
        ) ;let*
      ) ;lambda
    ) ;define

    ;; 401 后强制刷新：更新内存 store 并把 refresh/expires 落盘；access 仅内存。
    (define (pi-make-refresh-oauth-hook captured-env captured-dir)
      (lambda (cfg current-key)
        (let* ((p (pi-cfg-ref cfg 'provider #f))
               (store (pi-oauth-store-for-config cfg captured-env captured-dir))
               (cred (and p (pi-oauth-store-ref store p)))
              ) ;
          (and cred (%refresh! store cred captured-env captured-dir))
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
            (cons 'refresh-oauth-key (if cred (pi-make-refresh-oauth-hook env dir-str) #f))
          ) ;list
        ) ;pi-cfg-merge
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
