;; pi-app-handle-oauth-device-code!
;; 处理 kimi_oauth_device_code 事件：挂载 device-code 组件展示 user_code/URL。
;;
;; 语法
;; ----
;; (pi-app-handle-oauth-device-code! app ev)
;;
;; 参数
;; ----
;; app : pi-app?
;; 交互式应用实例。
;;
;; ev : list?
;; (kimi_oauth_device_code provider user-code uri interval expires)。
;;
;; 返回值
;; ----
;; any
;; 副作用：active-selector 变为 login-device-code 组件。

(import (scheme base)
  (liii check)
  (liii tui)
  (liii pi app interactive state)
  (liii pi app interactive app)
  (liii pi app interactive login-device-code)
  (liii pi app interactive app-login)
) ;import

(check-set-mode! 'report-failed)

(let ((app (make-pi-app
             :terminal (make-virtual-terminal :width 80 :height 24)
             :handler  (lambda (a m) #t)
             :provider "kimi-coding"
             :model    "k3-256k"
           ) ;make-pi-app
      ) ;app
     ) ;
  (pi-app-handle-oauth-device-code! app
    '(kimi_oauth_device_code "kimi-coding" "ABCD-1234"
       "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234" 1 900)
  ) ;pi-app-handle-oauth-device-code!
  (let ((sel (pi-app-active-selector app)))
    (check-true (login-device-code? sel))
    (check (login-device-code-user-code sel) => "ABCD-1234")
    (check (login-device-code-verification-uri sel)
      =>
      "https://www.kimi.com/code/authorize_device?user_code=ABCD-1234"
    ) ;check
    (check-false (login-device-code-cancelled? sel))
  ) ;let
) ;let

(check-report)
