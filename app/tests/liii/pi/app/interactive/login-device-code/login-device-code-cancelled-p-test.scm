;; login-device-code-cancelled?
;; 读取取消标志：Esc/Ctrl-C 后置位，供轮询循环 cancelled? 谓词探测。
;;
;; 语法
;; ----
;; (login-device-code-cancelled? comp) -> boolean?
;;
;; 参数
;; ----
;; comp : login-device-code?
;; device-code 组件。
;;
;; 返回值
;; ----
;; boolean?
;; 初始 #f；escape/ctrl-c 输入后 #t。

(import (liii check)
  (liii tui component)
  (liii pi app interactive login-device-code)
) ;import

(check-set-mode! 'report-failed)

(let* ((cancelled-calls 0)
       (comp
         (make-login-device-code "kimi-coding"
           "ABCD-1234"
           "https://x.example"
           (lambda () (set! cancelled-calls (+ cancelled-calls 1)))
         ) ;make-login-device-code
       ) ;comp
      ) ;
  (check-false (login-device-code-cancelled? comp))
  (component-handle-input comp 'escape)
  (check-true (login-device-code-cancelled? comp))
  (check cancelled-calls => 1)
) ;let*

(let ((comp (make-login-device-code "kimi-coding" "A" "https://x.example" (lambda () #f))
      ) ;comp
     ) ;
  (component-handle-input comp 'ctrl-c)
  (check-true (login-device-code-cancelled? comp))
) ;let

;; 其它按键不置位
(let ((comp (make-login-device-code "kimi-coding" "A" "https://x.example" (lambda () #f))
      ) ;comp
     ) ;
  (component-handle-input comp #\a)
  (check-false (login-device-code-cancelled? comp))
) ;let

(check-report)
