;; pi-code-review-config
;; 构造只读结构化审查使用的配置副本：tools 始终替换为空列表，其余配置保留。
;;
;; 语法
;; ----
;; (pi-code-review-config cfg)
;;
;; 参数
;; ----
;; cfg : alist? | pi-config?
;; 当前会话配置。
;;
;; 返回值
;; ----
;; alist 配置或 pi-config 副本；不修改输入。

(import (liii check) (liii pi code config) (gfcode code-review request))

(check-set-mode! 'report-failed)

(let* ((original (list (cons 'tools '("write")) (cons 'provider "google")))
       (result (pi-code-review-config original))
      ) ;
  (check (cdr (assoc 'tools result)) => '())
  (check (cdr (assoc 'provider result)) => "google")
  (check (cdr (assoc 'tools original)) => '("write"))
) ;let*

;; 实际 CLI 使用 pi-config record，而非测试用的 alist。
(let* ((original (make-pi-config :provider "google" :tools '("write")))
       (result (pi-code-review-config original))
      ) ;
  (check (pi-cfg-ref result 'tools) => '())
  (check (pi-cfg-ref result 'provider) => "google")
  (check (pi-cfg-ref original 'tools) => '("write"))
) ;let*

(check-report)
