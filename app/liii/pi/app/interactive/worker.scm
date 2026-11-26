;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License

(define-library (liii pi app interactive worker)
  ;; worker 线程通过重新 import 库并求值 procedure-source 执行，调用链内部函数须全部导出
  (export make-tui-emit pi-tui-agent-worker pi-tui-run-worker pi-tui-send-event!
    pi-cfg-with-thinking pi-cfg-with-model %worker-job-cfg %cfg-override
    pi-worker-ensure-session-file! pi-worker-handle-job %assistant-error-text
    %poll-one-injected %pi-worker-poll-cfg %worker-cfg-with-session-id
    %job-explicit
  ) ;export
  (import (scheme base)
    (scheme write)
    (scheme process-context)
    (liii go)
    (liii list)
    (liii string)
    (liii path)
    (liii pi ai abort)
    (liii pi ai auth)
    (liii pi ai config credential)
    (liii pi ai config model-metadata)
    (liii pi ai models meta)
    (liii pi ai models route)
    (liii pi code cli args)
    (liii pi code config)
    (liii pi code config user-catalog)
    (liii pi code core session-manager)
    (liii pi code core session-name)
    (liii pi code core session-stats)
    (liii pi code session-state)
    (liii pi ai retry)
    (liii pi code core extension-notify)
    (liii pi code core extensions)
    (liii pi app interactive diff-capture)
    (liii pi app interactive worker-emit)
    (liii pi app interactive worker-model)
    (liii pi code modes flow)
    (liii pi code modes output)
  ) ;import
  (begin

    (define (%cfg-override cfg pairs)
      (pi-cfg-merge cfg pairs)
    ) ;define

    ;; 轮询一条注入消息：非阻塞拉取并同步回发事件
    (define (%poll-one-injected chan event-chan)
      (let ((msg
              (and chan (catch #t (lambda () (chan-try-recv! chan #f)) (lambda args #f)))
            ) ;msg
           ) ;
        (if (and (string? msg) (not (string-null? msg)))
          (begin
            (pi-tui-send-event! event-chan (list 'user_message msg))
            (list msg)
          ) ;begin
          '()
        ) ;if
      ) ;let
    ) ;define

    ;; worker 运行期 cfg：注入 steering / follow-up 轮询回调，同名键一律替换
    (define (%pi-worker-poll-cfg cfg steering-chan follow-up-chan event-chan)
      (%cfg-override cfg
        (list (cons 'get-steering-messages
                (lambda () (%poll-one-injected steering-chan event-chan))
              ) ;cons
          (cons 'get-follow-up-messages
            (lambda () (%poll-one-injected follow-up-chan event-chan))
          ) ;cons
        ) ;list
      ) ;%cfg-override
    ) ;define

    (define (pi-cfg-with-thinking cfg tl . opt-explicit)
      (pi-cfg-merge cfg
        (cons (cons 'thinking-level tl)
          (if (pair? opt-explicit)
            (list (cons 'thinking-level-explicit? (car opt-explicit)))
            (if (pi-cfg-ref cfg 'thinking-level-explicit?)
              (list (cons 'thinking-level-explicit? #t))
              '()
            ) ;if
          ) ;if
        ) ;cons
      ) ;pi-cfg-merge
    ) ;define

    ;; 覆盖 cfg 的模型相关项（会话内 /model 切换后下一条消息生效，对齐上游 setModel）。
    ;; 1404：委派 worker-model 的共享实现，含 oauth 401 刷新钩子重同步。
    (define (pi-cfg-with-model cfg provider model-id)
      (pi-worker-merge-model cfg provider model-id)
    ) ;define

    (define (%job-explicit job cfg)
      (if (>= (length job) 5)
        (list-ref job 4)
        (pi-cfg-ref cfg 'thinking-level-explicit?)
      ) ;if
    ) ;define

    (define (%worker-job-cfg cfg job . opt-parsed)
      (let* ((base (pi-cfg-with-thinking cfg (cadr job) (%job-explicit job cfg)))
             (model-job? (and (> (length job) 3) (string? (list-ref job 2)) (string? (list-ref job 3)))
             ) ;model-job?
             (provider (and model-job? (list-ref job 2)))
             (old-provider (pi-cfg-ref cfg 'provider))
            ) ;
        (if (not model-job?)
          base
          (let ((cfg* (pi-cfg-with-model base provider (list-ref job 3))))
            (if (equal? provider old-provider)
              cfg*
              (augment-pi-config cfg* (if (pair? opt-parsed) (car opt-parsed) #f))
            ) ;if
          ) ;let
        ) ;if
      ) ;let*
    ) ;define

    (define (%worker-cfg-with-session-id cfg session-file)
      (if (string? session-file)
        (%cfg-override cfg (list (cons 'session-id session-file)))
        cfg
      ) ;if
    ) ;define

    (define (%cfg-context-window cfg)
      (let ((meta (pi-cfg-ref cfg 'model-meta)))
        (cond ((pi-model-metadata? meta) (pi-model-metadata-context-window meta))
              ((pair? meta)
               (let ((pair (assoc 'context-window meta)))
                 (if pair (cdr pair) #f)
               ) ;let
              ) ;
              (else #f)
        ) ;cond
      ) ;let
    ) ;define

    (define (%worker-assert-cred! cfg)
      (let ((m (pi-missing-credential-msg cfg)))
        (when m
          (error 'credential-error
            (string-append m ". Use /login to configure an API key.")
          ) ;error
        ) ;when
      ) ;let
    ) ;define

    (define* (pi-tui-run-worker parsed
               cfg
               user-text
               event-chan
               (session-file #f)
               (window #f)
               (diff #f)
             ) ;pi-tui-run-worker
      (%pi-with-turn-diff diff
        cfg
        (make-tui-emit event-chan (or window (%cfg-context-window cfg)))
        (lambda (run-cfg emit)
          (catch #t
            (lambda ()
              (%worker-assert-cred! run-cfg)
              (run-session-flow parsed
                (%worker-cfg-with-session-id run-cfg session-file)
                user-text
                emit
                (lambda (res-msgs) #t)
                session-file
                '()
                #f
              ) ;run-session-flow
            ) ;lambda
            (lambda (tag . err-args)
              (pi-tui-send-event! event-chan
                (list 'error
                  (string-append (object->string tag) ": " (object->string err-args))
                ) ;list
              ) ;pi-tui-send-event!
              (pi-tui-send-event! event-chan (list 'agent_settled #f))
            ) ;lambda
          ) ;catch
        ) ;lambda
      ) ;%pi-with-turn-diff
    ) ;define*

    (define (pi-worker-ensure-session-file! parsed cfg sfile-box)
      (unless (vector-ref sfile-box 0)
        (let-values (((sf _sdir) (setup-session-file-with-name parsed cfg (path->string (path-cwd))))
                    ) ;
          (vector-set! sfile-box 0 sf)
        ) ;let-values
      ) ;unless
      (vector-ref sfile-box 0)
    ) ;define

    (define (%worker-reload-cfg cfg job event-chan)
      (let* ((dir
               (if (and (> (length job) 1) (cadr job)) (cadr job) (pi-cfg-config-dir cfg))
             ) ;dir
             (dir-str (if (string? dir) dir (path->string dir)))
             (cur-p (pi-cfg-ref cfg 'provider))
             (new-key (and cur-p (pi-resolve-provider-key cur-p (pi-load-auth dir-str) '() dir-str))
             ) ;new-key
             ;; 重建成功后投递 models_updated，触发 app-events 重建 models/default-model
             (models-store (pi-build-user-catalog dir-str))
            ) ;
        ;; worker reload_models 成功后回灌主 app：按新白名单重建
        ;; pi-app-models/default-model 并重渲，使 /model 即时可见新登录 provider
        (pi-tui-send-event! event-chan (list 'models_updated dir-str))
        ;; 1404：/login 或刷新凭据后 reload 须重同步 oauth 401 刷新钩子，
        ;; 否则启动时无 oauth 凭据的会话登录后仍按现状 401 失败
        (pi-sync-oauth-refresh-hook
          (%cfg-override
            ;; /login 已更新 auth.json；丢弃旧内存快照后重新初始化。
            (pi-cfg-set cfg 'oauth-store #f)
            (list (cons 'models-store models-store)
              (cons 'settings (pi-load-settings dir))
              (cons 'api-key new-key)
            ) ;list
          ) ;%cfg-override
        ) ;pi-sync-oauth-refresh-hook
      ) ;let*
    ) ;define

    (define* (pi-worker-handle-job job
               parsed
               cfg
               sfile-box
               event-chan
               abort-chan
               (steering-chan #f)
               (follow-up-chan #f)
               (eff-box #f)
               (req-sel-chan #f)
               (display-jobs #f)
               (run-id #f)
             ) ;pi-worker-handle-job
      (let* ((cfg (%pi-worker-poll-cfg cfg steering-chan follow-up-chan event-chan))
             (effective-cfg cfg)
            ) ;
        (cond
         ((and (pair? job) (eq? (car job) 'bash_record))
          (catch #t
            (lambda ()
              (append-bash-execution! (pi-worker-ensure-session-file! parsed cfg sfile-box)
                (cadr job)
                (caddr job)
                (cadddr job)
              ) ;append-bash-execution!
            ) ;lambda
            (lambda (tag . args)
              (pi-tui-send-event! event-chan
                (list 'error
                  (string-append "bash record failed: " (object->string (cons tag args)))
                ) ;list
              ) ;pi-tui-send-event!
            ) ;lambda
          ) ;catch
         ) ;
         ((and (pair? job) (eq? (car job) 'session_stats))
          (catch #t
            (lambda ()
              (let* ((sfile (pi-worker-ensure-session-file! parsed cfg sfile-box))
                     (stats (pi-get-session-stats sfile))
                    ) ;
                (pi-tui-send-event! event-chan (list 'session_stats stats))
              ) ;let*
            ) ;lambda
            (lambda (tag . args)
              (pi-tui-send-event! event-chan
                (list 'session_stats_error
                  (string-append "Failed to read session stats: "
                    (object->string (cons tag args))
                  ) ;string-append
                ) ;list
              ) ;pi-tui-send-event!
            ) ;lambda
          ) ;catch
         ) ;
         ((and (pair? job) (eq? (car job) 'session_name))
          (catch #t
            (lambda ()
              (let ((name (pi-normalize-session-name (cadr job))))
                (append-session-info! (pi-worker-ensure-session-file! parsed cfg sfile-box)
                  name
                ) ;append-session-info!
                (pi-tui-send-event! event-chan (list 'session_name_changed name))
              ) ;let
            ) ;lambda
            (lambda (tag . args)
              (pi-tui-send-event! event-chan
                (list 'session_name_error
                  (string-append "Failed to set session name: " (object->string (cons tag args)))
                ) ;list
              ) ;pi-tui-send-event!
            ) ;lambda
          ) ;catch
         ) ;
         ((and (pair? job) (eq? (car job) 'session_state))
          (catch #t
            (lambda ()
              (append-session-state-entry! (pi-worker-ensure-session-file! parsed cfg sfile-box)
                (cadr job)
                (caddr job)
              ) ;append-session-state-entry!
            ) ;lambda
            (lambda (tag . args)
              (pi-tui-send-event! event-chan
                (list 'session_state_error
                  (string-append "Failed to record session state: "
                    (object->string (cons tag args))
                  ) ;string-append
                ) ;list
              ) ;pi-tui-send-event!
            ) ;lambda
          ) ;catch
         ) ;
         ((and (pair? job) (eq? (car job) 'session_resume))
          (catch #t
            (lambda ()
              (let* ((path (cadr job)) (normalized (if (string? path) path (path->string path))))
                (cond ((pi-args-ref parsed 'no-session)
                       (pi-tui-send-event! event-chan
                         (list 'session_resume_error "Session persistence is disabled (--no-session)")
                       ) ;pi-tui-send-event!
                      ) ;
                      ((not (file-exists? normalized))
                       (pi-tui-send-event! event-chan
                         (list 'session_resume_error
                           (string-append "Session file not found: " normalized)
                         ) ;list
                       ) ;pi-tui-send-event!
                      ) ;
                      (else (vector-set! sfile-box 0 normalized)
                        (pi-tui-send-event! event-chan
                          (list 'session_resumed
                            normalized
                            (get-session-name normalized)
                            (pi-session-state-of normalized)
                          ) ;list
                        ) ;pi-tui-send-event!
                      ) ;else
                ) ;cond
              ) ;let*
            ) ;lambda
            (lambda (tag . args)
              (pi-tui-send-event! event-chan
                (list 'session_resume_error
                  (string-append "Failed to resume session: " (object->string (cons tag args)))
                ) ;list
              ) ;pi-tui-send-event!
            ) ;lambda
          ) ;catch
         ) ;
         ((and (pair? job) (eq? (car job) 'reload_models))
          (catch #t
            (lambda () (set! effective-cfg (%worker-reload-cfg cfg job event-chan)))
            (lambda args #f)
          ) ;catch
          (when eff-box
            (pi-effective-cfg-set! eff-box effective-cfg)
          ) ;when
         ) ;
         (else (pi-abort-arm-chan! abort-chan)
           (let* ((job-cfg (%worker-job-cfg cfg job parsed))
                  ;; /model 或 /thinking 变更由 prepare-request 在请求前读取。
                  (eff-local (or eff-box (pi-make-effective-cfg-box job-cfg)))
                 ) ;
             (when eff-box
               (pi-effective-cfg-set! eff-box job-cfg)
             ) ;when
             (let* ((prepare (pi-worker-make-prepare-request eff-local req-sel-chan parsed))
                    (cfg-with-prepare (pi-cfg-merge job-cfg (list (cons 'prepare-request prepare))))
                    ;; 优先使用 all-in-one 节点窗口，否则使用 effective-cfg。
                    (window-getter (lambda () (%cfg-context-window (pi-effective-cfg-ref eff-local)))
                    ) ;window-getter
                   ) ;
               (set! effective-cfg job-cfg)
               (pi-tui-run-worker parsed
                 cfg-with-prepare
                 (car job)
                 event-chan
                 (pi-worker-ensure-session-file! parsed cfg sfile-box)
                 window-getter
                 (and display-jobs (%pi-make-diff-capture run-id display-jobs event-chan))
               ) ;pi-tui-run-worker
             ) ;let*
           ) ;let*
         ) ;else
        ) ;cond
        effective-cfg
      ) ;let*
    ) ;define*

    (define* (pi-tui-agent-worker jobs-chan
               event-chan
               abort-chan
               (initial-session-file #f)
               (steering-chan #f)
               (follow-up-chan #f)
               (request-selection-chan #f)
               (display-jobs #f)
             ) ;pi-tui-agent-worker
      ;; 按 discovery 仲裁加载扩展，再解析扩展 flag，避免重复挂载。
      (default-extension-registry)
      (let* ((parsed (parse-pi-args (cdr (command-line))))
             (cfg (augment-pi-config (resolve-pi-config parsed (get-environment-variables))
                    parsed
                  ) ;augment-pi-config
             ) ;cfg
             (sfile-box (vector initial-session-file))
             (eff-box (pi-make-effective-cfg-box cfg))
            ) ;
        (set-pi-retry-logger! (lambda (msg) (pi-tui-send-event! event-chan (list 'retry msg)))
        ) ;set-pi-retry-logger!
        ;; arm 扩展通知：worker 会话内生效（go 起独立 s7 会话），扩展经 ctx.ui.notify
        ;; 输出提示行由此投递回主线程渲染为聊天区状态行（同属会话级注入模式）
        (pi-extension-notify-set! (lambda (msg) (pi-tui-send-event! event-chan (list 'tps_report msg)) #t)
        ) ;pi-extension-notify-set!
        (let loop
          ((current-cfg cfg) (run-id 1))
          (let ((job (chan-recv! jobs-chan)))
            (when (and job (not (eof-object? job)))
              (loop (pi-worker-handle-job job parsed current-cfg sfile-box
                      event-chan abort-chan steering-chan follow-up-chan eff-box
                      request-selection-chan display-jobs run-id
                    ) ;pi-worker-handle-job
                (+ run-id 1)
              ) ;loop
            ) ;when
          ) ;let
        ) ;let
      ) ;let*
    ) ;define*
  ) ;begin
) ;define-library
