;; pi-app-handle-oauth-done!
;; 处理 kimi_oauth_done 事件：成功落盘 auth.json + reload_models + 上屏，
;; 失败上屏错误卡片，用户取消静默收尾。
;;
;; 语法
;; ----
;; (pi-app-handle-oauth-done! app ev)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; ev : list?
;; (kimi_oauth_done provider access refresh expires region err-tag err-msg)。
;;
;; 返回值
;; ----
;; any
;; 副作用：凭据落盘（GF_CONFIG_DIR 目录）、选择器关闭、卡片上屏。

(import (scheme base)
  (liii check)
  (liii os)
  (liii string)
  (liii list)
  (liii path)
  (liii json)
  (liii go)
  (liii tempfile)
  (liii tui)
  (liii tui component)
  (liii pi ai auth)
  (liii pi ai config credential)
  (liii pi tui interactive state)
  (liii pi tui interactive app)
  (liii pi tui interactive app-login)
) ;import

(check-set-mode! 'report-failed)

(define (make-test-app)
  (make-pi-app
    :terminal (make-virtual-terminal :width 80 :height 24)
    :handler  (lambda (a m) #t)
    :provider "kimi-coding"
    :model    "k3-256k"
  ) ;make-pi-app
) ;define

(define (chat-lines app)
  (apply append (map (lambda (c) (component-render c 80)) (pi-app-chat app)))
) ;define

;; 1. 成功：落盘 oauth 凭据、激活 provider、关闭选择器、上屏 Saved、发 reload_models
(let* ((tmp (make-temp-dir "gf-oauth-done-" ""))
       (saved-env (getenv "GF_CONFIG_DIR"))
       (app (make-test-app))
      ) ;
  (putenv "GF_CONFIG_DIR" tmp)
  (path-mkdir (path-join tmp "models") :parents #t :exist-ok #t)
  (path-write-text (path-join tmp "models" "providers.json") "[\"google\"]\n")
  (pi-app-handle-oauth-done! app
    (list 'kimi_oauth_done "kimi-coding" "acc-tok" "ref-tok" 1893456000000 #f #f #f)
  ) ;pi-app-handle-oauth-done!
  (check-false (pi-app-active-selector app))
  (let ((creds (pi-load-auth tmp)))
    (check (length creds) => 1)
    (check-true (pi-credential-oauth? (car creds)))
    (check (pi-credential-access (car creds)) => "acc-tok")
  ) ;let
  ;; 保留原白名单并激活 OAuth provider，随后 reload_models 会刷新 /model
  (let ((wl (string->json (path-read-text (path-join tmp "models" "providers.json")))))
    (check (vector->list wl) => '("google" "kimi-coding"))
  ) ;let
  (check-true (any (lambda (l) (string-contains? l "Saved OAuth credential for kimi-coding"))
                (chat-lines app)
              ) ;any
  ) ;check-true
  ;; reload_models 任务已入队
  (let ((job (chan-recv! (pi-app-jobs-chan app) 1000 'none)))
    (check (and (pair? job) (car job)) => 'reload_models)
  ) ;let
  (if saved-env (putenv "GF_CONFIG_DIR" saved-env) (unsetenv "GF_CONFIG_DIR"))
  (path-unlink (path (path-join tmp "auth.json")))
  (path-unlink (path-join tmp "models" "providers.json"))
  (path-rmdir (path-join tmp "models"))
  (path-rmdir tmp)
) ;let*

;; 2. 失败：错误卡片上屏，不落盘
(let* ((tmp (make-temp-dir "gf-oauth-done-" ""))
       (saved-env (getenv "GF_CONFIG_DIR"))
       (app (make-test-app))
      ) ;
  (putenv "GF_CONFIG_DIR" tmp)
  (pi-app-handle-oauth-done! app
    (list 'kimi_oauth_done "kimi-coding" #f #f #f #f 'kimi-oauth-error "denied")
  ) ;pi-app-handle-oauth-done!
  (check-false (pi-app-active-selector app))
  (check-true (any (lambda (l) (string-contains? l "OAuth login failed")) (chat-lines app))
  ) ;check-true
  (check (pi-load-auth tmp) => '())
  (if saved-env (putenv "GF_CONFIG_DIR" saved-env) (unsetenv "GF_CONFIG_DIR"))
  (path-rmdir tmp)
) ;let*

;; 3. 用户取消：静默，无错误卡片
(let ((app (make-test-app)))
  (pi-app-handle-oauth-done! app
    (list 'kimi_oauth_done
      "kimi-coding"
      #f
      #f
      #f
      #f
      'kimi-oauth-cancelled
      "Login cancelled"
    ) ;list
  ) ;pi-app-handle-oauth-done!
  (check-false (any (lambda (l) (string-contains? l "OAuth login failed")) (chat-lines app))
  ) ;check-false
) ;let

(check-report)
