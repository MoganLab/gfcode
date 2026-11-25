;; login-device-code-open-browser!
;; 打开浏览器访问验证 URL；Enter 触发，渲染提示随之切换。
;;
;; 语法
;; ----
;; (login-device-code-open-browser! comp)
;;
;; 参数
;; ----
;; comp : login-device-code?
;; device-code 组件。
;;
;; 返回值
;; ----
;; any
;; 副作用：调 web-browser-open（无浏览器环境静默失败），
;; 渲染显示「Browser opened」提示。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii tui component)
  (liii pi app interactive login-device-code)
) ;import

(check-set-mode! 'report-failed)

;; 初始渲染：提示手动打开
(let ((comp (make-login-device-code "kimi-coding" "A" "https://x.example" (lambda () #f))
      ) ;comp
     ) ;
  (check-true (any (lambda (l) (string-contains? l "manually")) (component-render comp 80))
  ) ;check-true
  ;; Enter 打开浏览器（headless 环境 web-browser-open 返回 #f，不抛错）
  (component-handle-input comp 'enter)
  (check-true (any (lambda (l) (string-contains? l "Browser opened"))
                (component-render comp 80)
              ) ;any
  ) ;check-true
  ;; 显式调用同样安全
  (login-device-code-open-browser! comp)
) ;let

(check-report)
