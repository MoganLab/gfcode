;; pi-code-review-parsed / pi-code-review-config
;; 构造只读结构化审查使用的参数与配置副本。
;;
;; 语法
;; ----
;; (pi-code-review-parsed parsed)
;; (pi-code-review-config cfg)
;;
;; 参数
;; ----
;; parsed : alist? | pi-cli-args?
;; 当前 CLI 参数。
;; cfg : alist?
;; 当前会话配置。
;;
;; 返回值
;; ----
;; 分别为同类型参数副本和 alist 配置。
;;
;; 错误行为
;; --------
;; 不修改输入；保留用户显式 system-prompt，配置中的 tools 始终替换为空列表。

(import (liii check)
  (liii pi code cli args)
  (liii pi code cli args query)
  (liii pi code config)
  (gfcode code-review request)
) ;import

(check-set-mode! 'report-failed)

(let* ((original (list (cons 'system-prompt "custom") (cons 'messages '("a.scm"))))
       (result (pi-code-review-parsed original))
      ) ;
  (check (pi-args-ref result 'system-prompt) => "custom")
  (check (pi-args-ref result 'messages) => '("a.scm"))
) ;let*

(let* ((original '((messages "a.scm"))) (result (pi-code-review-parsed original)))
  (check-true (string? (pi-args-ref result 'system-prompt)))
  (check (pi-args-ref original 'system-prompt) => #f)
) ;let*

(let* ((original (list (cons 'tools '("write")) (cons 'provider "google")))
       (result (pi-code-review-config original))
      ) ;
  (check (cdr (assoc 'tools result)) => '())
  (check (cdr (assoc 'provider result)) => "google")
  (check (cdr (assoc 'tools original)) => '("write"))
) ;let*

;; 实际 CLI 使用 pi-cli-args / pi-config record，而非测试用的 alist。
(let* ((original (make-pi-cli-args :messages '("a.scm")))
       (result (pi-code-review-parsed original))
      ) ;
  (check-true (string? (pi-args-ref result 'system-prompt)))
  (check (pi-args-ref original 'system-prompt) => #f)
) ;let*

(let* ((original (make-pi-config :provider "google" :tools '("write")))
       (result (pi-code-review-config original))
      ) ;
  (check (pi-cfg-ref result 'tools) => '())
  (check (pi-cfg-ref result 'provider) => "google")
  (check (pi-cfg-ref original 'tools) => '("write"))
) ;let*

(check-report)
