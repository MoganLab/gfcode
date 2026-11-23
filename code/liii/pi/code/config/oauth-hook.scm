;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 1404：oauth 401 强制刷新钩子的构造与按 provider 重同步。
;; resolve-pi-config 初始注入，以及会话内切模（含同 provider）/
;; /login 后 reload 时都须调用 pi-sync-oauth-refresh-hook：
;; 钩子闭包捕获 provider 无关的 env/dir，按 cfg 当前 provider 现查
;; auth.json，有 oauth 凭据则注入，无则移除旧钩子（避免切到非
;; oauth provider 后残留钩子误刷新）。
(define-library (liii pi code config oauth-hook)
  (import (scheme base)
    (scheme process-context)
    (liii path)
    (liii pi ai auth)
    ;; save!/remove! 闭包经 procedure-source 在 go worker 会话重建求值，
    ;; pi-credential-* 访问器须随本库进入会话活动库列表，否则 save! 抛
    ;; unbound 被吞、新 token 不落盘（下次启动仍用旧 token 反复 401）
    (liii pi ai config credential)
    (liii pi ai auth oauth resolve)
    (liii pi ai config runtime)
  ) ;import
  (export pi-make-refresh-oauth-hook pi-sync-oauth-refresh-hook)
  (begin

    ;; 构造 401 后强制刷新 oauth 凭据的闭包钩子。落盘/清除回调
    ;; 注入 auth.json 目录（captured-dir），env 表 captured-env 透传。
    (define (pi-make-refresh-oauth-hook captured-env captured-dir)
      (lambda (cfg current-key)
        (let* ((p (pi-cfg-ref cfg 'provider #f))
               (creds (if (pair? captured-env)
                        (pi-load-auth captured-dir captured-env)
                        (pi-load-auth captured-dir)
                      ) ;if
               ) ;creds
               (cred (pi-find-oauth-credential p creds))
              ) ;
          (if cred
            (pi-force-refresh-oauth-credential-key cred
              (if (pair? captured-env) captured-env '())
              (lambda (c)
                (pi-save-auth-oauth! (pi-credential-provider c)
                  (pi-credential-access c)
                  (pi-credential-refresh c)
                  (pi-credential-expires c)
                  (pi-credential-region c)
                  captured-dir
                ) ;pi-save-auth-oauth!
              ) ;lambda
              (lambda (pp) (pi-remove-auth-provider! pp captured-dir))
            ) ;pi-force-refresh-oauth-credential-key
            #f
          ) ;if
        ) ;let*
      ) ;lambda
    ) ;define

    ;; 按 cfg 当前 provider 同步 refresh-oauth-key 钩子：
    ;; 有 oauth 凭据 → 注入（覆盖旧钩子，目录取 cfg 现值）；
    ;; 无 → 置 #f 移除残留钩子（非 oauth provider 的 401 按现状失败）。
    ;; opt-env 为 (env-alist) 形式，缺省取当前进程环境变量。
    (define (pi-sync-oauth-refresh-hook cfg . opt-env)
      (let* ((env (if (pair? opt-env) (car opt-env) (get-environment-variables)))
             ;; 与 pi-cfg-config-dir 同义：优先 config-dir，缺失回退 agent-dir
             ;; （就地取避免引入 (liii pi code config) 循环依赖）
             (dir (or (pi-cfg-ref cfg 'config-dir) (pi-cfg-ref cfg 'agent-dir)))
             (dir-str (if (path? dir) (path->string dir) dir))
             (provider (pi-cfg-ref cfg 'provider #f))
             (creds (pi-load-auth dir-str env))
            ) ;
        (pi-cfg-set cfg
          'refresh-oauth-key
          (if (pi-has-oauth-credential? provider creds)
            (pi-make-refresh-oauth-hook env dir-str)
            #f
          ) ;if
        ) ;pi-cfg-set
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
