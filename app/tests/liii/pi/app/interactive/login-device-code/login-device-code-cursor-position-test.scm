;; login-device-code-cursor-position
;; 组件光标相对坐标（无输入行，固定停靠在标题下方）。
;;
;; 语法
;; ----
;; (login-device-code-cursor-position comp) -> list?
;;
;; 参数
;; ----
;; comp : login-device-code?
;; device-code 组件。
;;
;; 返回值
;; ----
;; list?
;; (row col) 整数列表，与 render 布局一致。

(import (liii check) (liii pi app interactive login-device-code))

(check-set-mode! 'report-failed)

(let ((comp (make-login-device-code "kimi-coding" "A" "https://x.example" (lambda () #f))
      ) ;comp
     ) ;
  (check (login-device-code-cursor-position comp) => '(4 2))
) ;let

(check-report)
