;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; oauth 凭据解析与透明刷新（1402 §5.2）：pi-resolve-provider-key 的
;; oauth 分支。落盘/清除通过注入的 save!/remove! 回调完成，避免与
;; (liii pi ai auth) 循环依赖；gfcode 单进程无需文件锁（对应 pi
;; Models.getAuth() 在 store lock 内 refresh 的简化版）。
(define-library (liii pi ai auth oauth resolve)
  (import (scheme base)
    (liii pi ai config credential)
    (liii pi ai auth oauth kimi-coding-oauth)
    (liii pi ai time)
  ) ;import
  (export pi-find-oauth-credential pi-resolve-oauth-credential-key
    ;; go worker 会话重求值调用链上的助手须导出
    %pi-refresh-oauth-credential!
    ;; 1404：请求层收到 401 后的强制刷新（不查 expires）与凭据探测
    pi-force-refresh-oauth-credential-key pi-has-oauth-credential?
  ) ;export
  (begin

    ;; 在凭据列表中按 provider 精确匹配 oauth 凭据
    (define (pi-find-oauth-credential target auth-list)
      (and target
        (let loop
          ((xs auth-list))
          (if (null? xs)
            #f
            (let ((item (car xs)))
              (if (and (pi-credential-oauth? item)
                    (equal? (pi-credential-provider item) target)
                  ) ;and
                item
                (loop (cdr xs))
              ) ;if
            ) ;let
          ) ;if
        ) ;let
      ) ;and
    ) ;define

    ;; oauth 凭据的 host：region（登录时落盘的覆盖值）> env 覆盖 > 默认国内 host
    (define (%oauth-credential-host cred opt-env)
      (or (pi-credential-region cred)
        (kimi-oauth-host (if (pair? opt-env) (car opt-env) '()))
      ) ;or
    ) ;define

    ;; 刷新 oauth 凭据并经 save! 落盘。401/403/invalid_grant 时经 remove!
    ;; 清除凭据并返回 #f 触发重新 /login；其余失败（网络/5xx 重试用尽）
    ;; 保留凭据返回 #f，不携带失效 token 继续请求。
    ;; save! : (lambda (cred) ...)  remove! : (lambda (provider) ...)
    (define (%pi-refresh-oauth-credential! cred opt-env save! remove!)
      (let* ((provider (pi-credential-provider cred))
             (host (%oauth-credential-host cred opt-env))
             (refreshed
               (catch #t
                 (lambda ()
                   (kimi-refresh-token host (pi-credential-refresh cred)
                     provider (pi-credential-region cred)
                   ) ;kimi-refresh-token
                 ) ;lambda
                 (lambda (tag . info) (cons tag info))
               ) ;catch
             ) ;refreshed
            ) ;
        (cond
         ((pi-credential? refreshed)
          (catch #t (lambda () (save! refreshed)) (lambda args #f))
          (pi-credential-access refreshed)
         ) ;
         ((and (pair? refreshed) (eq? (car refreshed) 'kimi-oauth-unauthorized))
          (catch #t (lambda () (remove! provider)) (lambda args #f))
          #f
         ) ;
         (else #f)
        ) ;cond
      ) ;let*
    ) ;define

    ;; oauth 凭据 → access token：未过期（留 60s 缓冲）直接返回 access，
    ;; 过期则透明刷新并落盘后返回新 access
    (define (pi-resolve-oauth-credential-key cred opt-env save! remove!)
      (let ((expires (pi-credential-expires cred)))
        (if (> expires (+ (pi-current-time-millis) 60000))
          (pi-credential-access cred)
          (%pi-refresh-oauth-credential! cred opt-env save! remove!)
        ) ;if
      ) ;let
    ) ;define

    ;; 1404：强制刷新（不查 expires），供请求层收到 401 后回退使用。
    ;; 语义与 pi-resolve-oauth-credential-key 的过期分支一致，仅省略 expires
    ;; 判断：直接走 %pi-refresh-oauth-credential!，成功落盘返回新 access，
    ;; 401/403/invalid_grant 经 remove! 清除并返回 #f，其余失败保留凭据返回 #f。
    (define (pi-force-refresh-oauth-credential-key cred opt-env save! remove!)
      (%pi-refresh-oauth-credential! cred opt-env save! remove!)
    ) ;define

    ;; 1404：在凭据列表中探测 provider 是否有 oauth 凭据，供 config 注入
    ;; refresh-oauth-key 钩子时判定（无 oauth 凭据则不注入，401 按现状失败）
    (define (pi-has-oauth-credential? target auth-list)
      (and (pi-find-oauth-credential target auth-list) #t)
    ) ;define

  ) ;begin
) ;define-library