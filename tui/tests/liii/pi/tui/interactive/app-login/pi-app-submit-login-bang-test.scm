;; pi-app-submit-login!
;; 处理 /login 命令的提交，挂载选择器或对话框，或直接保存 Key。
;;
;; 语法
;; ----
;; (pi-app-submit-login! app text)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; text : string?
;; 用户输入的命令文本（如 "/login"）。
;;
;; 返回值
;; ----
;; any
;; 执行界面切换或持久化副作用。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii path)
  (liii json)
  (liii os)
  (liii tempfile)
  (liii tui)
  (liii go)
  (liii pi ai auth)
  (liii pi tui interactive state)
  (liii pi tui interactive app)
  (liii pi tui interactive login-selector)
  (liii pi tui interactive login-dialog)
  (liii pi tui interactive app-login)
) ;import

(check-set-mode! 'report-failed)

;; 读取 models/providers.json 白名单为字符串列表；文件缺失返回 #f

(define (read-whitelist dir)
  (let* ((wl (path-join dir "models" "providers.json"))
         (exists (path-exists? wl))
         (data
           (and exists (string->json (path-read-text (path wl))))
         ) ;data
        ) ;
    (and (vector? data) (vector->list data))
  ) ;let*
) ;define

;; 取路径末尾目录名（用 path-parts，跨平台）

(define (path-last-name p-str)
  (let* ((parts (path-parts (path p-str))) (n (vector-length parts)))
    (vector-ref parts (- n 1))
  ) ;let*
) ;define

;; 构造用于单元测试的最小 mock app

(define (make-test-app tmp-dir)
  (let ((term (make-virtual-terminal :width 80 :height 24)))
    (make-pi-app :terminal term :provider "deepseek" :model "deepseek-chat")
  ) ;let
) ;define

;; 1. /login 唤起供应商选择器
(let* ((tmp (make-temp-dir "gf-login-test-" "")) (app (make-test-app tmp)))
  (pi-app-submit-login! app "/login")
  (check-true (login-selector? (pi-app-active-selector app)))

  ;; Esc 取消选择器
  (component-handle-input (pi-app-active-selector app) 'escape)
  (check-false (pi-app-active-selector app))

  (path-rmdir tmp)
) ;let*

;; 2. /login <provider> 直接唤起该供应商的 Key 对话框
(let* ((tmp (make-temp-dir "gf-login-test-" "")) (app (make-test-app tmp)))
  (pi-app-submit-login! app "/login kimi-coding")
  (let ((selector (pi-app-active-selector app)))
    (check-true (login-dialog? selector))
    (check (login-dialog-provider selector) => "kimi-coding")
    ;; Esc 取消对话框
    (component-handle-input selector 'escape)
    (check-false (pi-app-active-selector app))
  ) ;let

  (path-rmdir tmp)
) ;let*

;; 3. /login <provider> <key> 直接写入 auth.json 与 providers.json 白名单
(let* ((tmp (make-temp-dir "gf-login-test-" ""))
       (app (make-test-app tmp))
       (auth-target (path->string (path-join tmp "auth.json")))
      ) ;
  (pi-save-auth-key "zai-coding-cn" "sk-zai-123" tmp)
  (let ((creds (pi-load-auth tmp)))
    (check (length creds) => 1)
    (check (pi-resolve-provider-key "zai-coding-cn" creds '()) => "sk-zai-123")
  ) ;let
  ;; 白名单已包含 zai-coding-cn
  (let ((wl (read-whitelist tmp)))
    (check-true (and (pair? wl) (member "zai-coding-cn" wl) #t))
  ) ;let
  (path-unlink (path auth-target))
  (let ((wl-file (path-join tmp "models" "providers.json")))
    (when (path-exists? wl-file)
      (path-unlink wl-file)
    ) ;when
  ) ;let
  (let ((models-dir (path-join tmp "models")))
    (when (path-exists? models-dir)
      (path-rmdir models-dir)
    ) ;when
  ) ;let
  (path-rmdir tmp)
) ;let*

;; 4. /login <provider> <key> 通过 GF_CONFIG_DIR 重定向写盘并投递 reload_models
(let* ((tmp (make-temp-dir "gf-login-flow-" ""))
       (saved-gf (getenv "GF_CONFIG_DIR"))
       (saved-pi (getenv "PI_CODING_AGENT_DIR"))
      ) ;
  (path-mkdir (path-join (path tmp) "models") :parents #t :exist-ok #t)
  (path-write-text (path-join (path tmp) "models" "providers.json")
    "[\"google\"]\n"
  ) ;path-write-text
  (putenv "GF_CONFIG_DIR" tmp)
  (unsetenv "PI_CODING_AGENT_DIR")
  (let* ((app (make-pi-app
                :terminal (make-virtual-terminal :width 80 :height 24)
                :provider "deepseek"
                :model    "deepseek-chat"
                :handler  (lambda (a m) #t)
              ) ;make-pi-app
         ) ;app
         (jobs (pi-app-jobs-chan app))
        ) ;
    (pi-app-submit-login! app "/login kimi-coding sk-kimi-flow")
    ;; 凭证已写入 auth.json
    (let ((creds (pi-load-auth tmp)))
      (check (length creds) => 1)
      (check (pi-resolve-provider-key "kimi-coding" creds '()) => "sk-kimi-flow")
    ) ;let
    ;; 白名单已包含 kimi-coding，且保留既有 google
    (let ((wl (read-whitelist tmp)))
      (check-true (and (pair? wl) (member "kimi-coding" wl) #t))
      (check-true (and (member "google" wl) #t))
    ) ;let
    ;; reload_models 任务已投递到 jobs-chan，载荷为 config-dir（gf-get-config-dir 返回 tmp）
    (let ((job (chan-try-recv! jobs #f)))
      (check-true (pair? job))
      (check (car job) => 'reload_models)
      ;; 载荷为指向 tmp 的路径字符串（macOS 下 /var 为 /private/var 符号链接，
      ;; gf-get-config-dir 会展开，故仅校验为字符串且末尾目录名与 tmp 一致）
      (check-true (string? (cadr job)))
      (check (path-last-name (cadr job)) => (path-last-name tmp))
    ) ;let
  ) ;let*
  ;; 还原环境变量
  (if saved-gf (putenv "GF_CONFIG_DIR" saved-gf) (unsetenv "GF_CONFIG_DIR"))
  (when saved-pi
    (putenv "PI_CODING_AGENT_DIR" saved-pi)
  ) ;when
  ;; 清理
  (path-unlink (path (path-join tmp "auth.json")))
  (let ((wl-file (path-join tmp "models" "providers.json")))
    (when (path-exists? wl-file)
      (path-unlink wl-file)
    ) ;when
  ) ;let
  (path-rmdir (path-join tmp "models"))
  (path-rmdir tmp)
) ;let*

(check-report)
