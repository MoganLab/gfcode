;; login-models-refresh 集成测试
;; 全链路验证：/login 写白名单 → 投递 reload_models → worker 按新白名单重建并发
;; models_updated → app 重建 pi-app-models/default-model 并重渲。
;;
;; 语法
;; ----
;; （本测试文件不导出函数，仅驱动全链路并断言 models/default-model 刷新）
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ------
;; unspecified
;; 无返回值。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii path)
  (liii json)
  (liii go)
  (liii tempfile)
  (liii tui)
  (liii pi ai auth)
  (liii pi code config user-catalog)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive app-events)
  (liii pi app interactive app-model)
  (liii pi app interactive worker)
) ;import

(check-set-mode! 'report-failed)

;; 定位测试 fixture 目录（运行时工作目录为 app/ 域根）

(define fixture-dir
  (path->string
    (path-absolute (path (if (file-exists? "tests/fixtures/user-config/config-tui")
                           "tests/fixtures/user-config/config-tui"
                           "tools/pi/tests/fixtures/user-config/config-tui"
                         ) ;if
                   ) ;path
    ) ;path-absolute
  ) ;path->string
) ;define

;; 模型条目中取 provider 字段

(define (model-provider m)
  (let ((p (assoc 'provider m)))
    (and p (cdr p))
  ) ;let
) ;define

(define (has-provider-model? models provider)
  (any (lambda (m) (equal? (model-provider m) provider)) models)
) ;define

;; 1. 全链路：login 写白名单 → reload_models 重建 → models_updated 回灌 app
(let* ((app (make-pi-app
              :terminal (make-virtual-terminal :width 80 :height 24)
              :handler  (lambda (a m) #t)
            ) ;make-pi-app
       ) ;app
       (jobs (pi-app-jobs-chan app))
       (event-ch (pi-app-event-chan app))
       (tmp (make-temp-dir "gf-1410-integ-" ""))
      ) ;
  ;; 1.1 准备临时 config-dir：只有 google 的白名单
  (path-mkdir (path-join (path tmp) "models") :parents #t :exist-ok #t)
  (path-write-text (path-join (path tmp) "models" "providers.json")
    "[\"google\"]\n"
  ) ;path-write-text

  ;; 1.2 初始 models 为空
  (check (length (pi-app-models app)) => 0)

  ;; 1.3 login deepseek：写 auth.json + 白名单追加 deepseek
  (pi-save-auth-key "deepseek" "sk-test-ds" tmp)
  (let ((wl
          (string->json (path-read-text (path-join (path tmp) "models" "providers.json")))
        ) ;wl
       ) ;
    (check-true (and (member "deepseek" (vector->list wl)) #t))
    (check-true (and (member "google" (vector->list wl)) #t))
  ) ;let

  ;; 1.4 模拟 app-login 的 pi-app-save-login-key! 投递 reload_models 任务
  (chan-send! jobs (list 'reload_models tmp))

  ;; 1.5 模拟 worker 消费 reload_models：调用 pi-worker-handle-job（不带 eff-box，
  ;;     避免 effective-cfg box 干扰），其内部 %worker-reload-cfg 重建后发 models_updated
  (let* ((parsed '())
         (dummy-cfg (list (cons 'provider "google")
                      (cons 'model-id "gemini-2.5-flash")
                      (cons 'models-store '())
                      (cons 'settings #f)
                      (cons 'config-dir tmp)
                    ) ;list
         ) ;dummy-cfg
         (box (vector #f))
        ) ;
    (pi-worker-handle-job (list 'reload_models tmp)
      parsed
      dummy-cfg
      box
      event-ch
      #f
    ) ;pi-worker-handle-job
  ) ;let*

  ;; 1.6 worker 已投递 models_updated 事件到 event-chan，poll 后 app 重建 models
  (pi-app-poll-events! app)
  (let ((models (pi-app-models app)))
    (check-true (pair? models))
    ;; 白名单含 google + deepseek，models 应包含两者的模型
    (check-true (has-provider-model? models "google"))
    (check-true (has-provider-model? models "deepseek"))
  ) ;let

  ;; 清理临时目录
  (let ((auth-file (path-join (path tmp) "auth.json")))
    (when (path-exists? auth-file)
      (path-unlink auth-file)
    ) ;when
  ) ;let
  (let ((wl-file (path-join (path tmp) "models" "providers.json")))
    (when (path-exists? wl-file)
      (path-unlink wl-file)
    ) ;when
  ) ;let
  (path-rmdir (path-join (path tmp) "models"))
  (path-rmdir (path tmp))
) ;let*

(check-report)
