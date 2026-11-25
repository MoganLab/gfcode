;; models_updated 事件处理
;; worker 的 reload_models 成功后投递 models_updated 事件，app-events 重建
;; pi-app-models/default-model 并重渲，使 /model 即时可见新登录 provider。
;;
;; 语法
;; ----
;; （本测试文件不导出函数，仅驱动事件处理并断言 models/default-model 刷新）
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
  (liii go)
  (liii tui)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive app-events)
  (liii pi app interactive app-model)
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

(define (model-id m)
  (let ((i (assoc 'id m)))
    (and i (cdr i))
  ) ;let
) ;define

;; 判断 models 列表中是否存在某 provider 的模型

(define (has-provider-model? models provider)
  (any (lambda (m) (equal? (model-provider m) provider)) models)
) ;define

;; 1. models_updated 事件后 pi-app-models 按新白名单重建
(let* ((app (make-pi-app
              :terminal (make-virtual-terminal :width 80 :height 24)
              :handler  (lambda (a m) #t)
            ) ;make-pi-app
       ) ;app
       (ch (pi-app-event-chan app))
      ) ;
  ;; 初始 models 为空
  (check (length (pi-app-models app)) => 0)
  ;; 投递 models_updated 事件，携带 fixture config-dir
  (chan-send! ch (list 'models_updated fixture-dir))
  (pi-app-poll-events! app)
  ;; 重建后 models 已按白名单填充，包含 fixture 中的 custom-kimi 与 kimi-coding
  (let ((models (pi-app-models app)))
    (check-true (pair? models))
    (check-true (has-provider-model? models "custom-kimi"))
    (check-true (has-provider-model? models "kimi-coding"))
  ) ;let
) ;let*

;; 2. default-model 按 settings.json 重建
(let* ((app (make-pi-app
              :terminal (make-virtual-terminal :width 80 :height 24)
              :handler  (lambda (a m) #t)
            ) ;make-pi-app
       ) ;app
       (ch (pi-app-event-chan app))
      ) ;
  (check-false (%pi-app-default-model app))
  (chan-send! ch (list 'models_updated fixture-dir))
  (pi-app-poll-events! app)
  ;; fixture 的 settings.json 指定 defaultProvider=kimi-coding, defaultModel=k3.1-pro
  (let ((dm (%pi-app-default-model app)))
    (check-true (pair? dm))
    (check (cdr (assoc 'provider dm)) => "kimi-coding")
    (check (cdr (assoc 'id dm)) => "k3.1-pro")
  ) ;let
) ;let*

;; 3. 事件不带 config-dir 时回退 gf-get-config-dir，不崩溃
(let* ((app (make-pi-app
              :terminal (make-virtual-terminal :width 80 :height 24)
              :handler  (lambda (a m) #t)
            ) ;make-pi-app
       ) ;app
       (ch (pi-app-event-chan app))
      ) ;
  ;; 仅投递事件符号，无 config-dir 载荷
  (chan-send! ch (list 'models_updated))
  (pi-app-poll-events! app)
  ;; 不崩溃即通过；models 重建结果取决于实际配置目录，此处仅验证无异常
  (check-true #t)
) ;let*

(check-report)
