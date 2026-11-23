;; pi-app-show-login-oauth!
;; 启动 OAuth 设备码登录：挂占位组件，后台 go worker 跑设备授权与轮询，
;; device_code/done 事件经 pi-app-poll-events! 上屏与落盘（stub 端到端）。
;;
;; 语法
;; ----
;; (pi-app-show-login-oauth! app provider)
;; (pi-app-show-login-oauth! app provider opt-config-dir)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; provider : string?
;; 服务商 id（kimi-coding）。
;;
;; opt-config-dir : (or string? path?)
;; 可选，配置目录。
;;
;; 返回值
;; ----
;; any
;; 副作用：挂载占位/设备码组件，事件驱动后续流转。

(import (scheme base)
  (liii check)
  (liii os)
  (scheme write)
  (liii go)
  (liii string)
  (liii list)
  (liii path)
  (liii time)
  (liii subprocess)
  (liii tempfile)
  (liii tui)
  (liii tui component)
  (liii pi ai auth)
  (liii pi ai config credential)
  (liii pi tui interactive state)
  (liii pi tui interactive app)
  (liii pi tui interactive login-device-code)
  (liii pi tui interactive app-login)
) ;import

(check-set-mode! 'report-failed)

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define stub-file
  (if (file-exists? "tests/stub_kimi_oauth_server.py")
    "tests/stub_kimi_oauth_server.py"
    (if (file-exists? "../ai/tests/stub_kimi_oauth_server.py")
      "../ai/tests/stub_kimi_oauth_server.py"
      "ai/tests/stub_kimi_oauth_server.py"
    ) ;if
  ) ;if
) ;define

(define (chat-lines app)
  (apply append (map (lambda (c) (component-render c 80)) (pi-app-chat app)))
) ;define

;; 完整链路：占位 → device-code 组件 → Saved 卡片 + 凭据落盘
(let* ((proc (process-spawn (list "python3" stub-file "ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (tmp (make-temp-dir "gf-oauth-show-" ""))
       (saved-env (getenv "GF_CONFIG_DIR"))
       (saved-host (getenv "KIMI_CODE_OAUTH_HOST"))
       (app (make-pi-app
              :terminal (make-virtual-terminal :width 80 :height 24)
              :handler  (lambda (a m) #t)
              :provider "kimi-coding"
              :model    "k3-256k"
            ) ;make-pi-app
       ) ;app
      ) ;
  (putenv "GF_CONFIG_DIR" tmp)
  (putenv "KIMI_CODE_OAUTH_HOST" host)
  (pi-app-show-login-oauth! app "kimi-coding" tmp)
  (sleep 1.5)
  (let drain ()
    (let ((ev (chan-try-recv! (pi-app-event-chan app) #f)))
      (when ev (display (list "RAWEV" ev)) (newline) (drain))))
  ;; drain 后 selector 仍是占位（device_code 已被消费掉）
  ;; 占位组件已挂载
  (check-true (component? (pi-app-active-selector app)))
  ;; 轮询事件直至 device-code 组件出现（最多 ~10s）
  (let wait
    ((n 0))
    (when
      (and (< n 100) (not (login-device-code? (pi-app-active-selector app))))
      (pi-app-poll-events! app)
      (sleep 0.1)
      (wait (+ n 1))
    ) ;when
  ) ;let
  (begin
    (display (list "SELCODE" (login-device-code-user-code (pi-app-active-selector app)))) (newline)
    (let ((ls (chat-lines app)))
      (for-each (lambda (l) (when (string-contains? l "HOST=") (display (list "LINE" l)) (newline))) ls)))
  (check-true (login-device-code? (pi-app-active-selector app)))
  (display (list "DBG" port host (getenv "KIMI_CODE_OAUTH_HOST") (login-device-code-user-code (pi-app-active-selector app)))) (newline)
  (check (login-device-code-user-code (pi-app-active-selector app))
    =>
    "ABCD-1234"
  ) ;check
  ;; 继续轮询直至登录完成（授权由 stub 自动完成）
  (let wait
    ((n 0))
    (when (and (< n 100) (pi-app-active-selector app))
      (pi-app-poll-events! app)
      (sleep 0.1)
      (wait (+ n 1))
    ) ;when
  ) ;let
  (when (pi-app-active-selector app)
    (display (list "ENDSEL" (login-device-code-user-code (pi-app-active-selector app)))) (newline))
  (check-false (pi-app-active-selector app))
  (check-true (any (lambda (l) (string-contains? l "Saved OAuth credential for kimi-coding"))
                (chat-lines app)
              ) ;any
  ) ;check-true
  (let ((creds (pi-load-auth tmp)))
    (check (length creds) => 1)
    (check (pi-credential-access (car creds)) => "stub-access-token")
    (check (pi-credential-region (car creds)) => host)
  ) ;let
  (if saved-env (putenv "GF_CONFIG_DIR" saved-env) (unsetenv "GF_CONFIG_DIR"))
  (if saved-host
    (putenv "KIMI_CODE_OAUTH_HOST" saved-host)
    (unsetenv "KIMI_CODE_OAUTH_HOST")
  ) ;if
  (process-kill proc)
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

(check-report)
