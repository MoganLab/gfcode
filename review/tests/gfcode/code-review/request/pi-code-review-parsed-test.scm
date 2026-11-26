;; pi-code-review-parsed
;; 构造只读结构化审查使用的参数副本：保留用户显式 system-prompt，否则注入只读
;; 审查 system prompt。
;;
;; 语法
;; ----
;; (pi-code-review-parsed parsed)
;;
;; 参数
;; ----
;; parsed : alist? | pi-cli-args?
;; 当前 CLI 参数。
;;
;; 返回值
;; ----
;; 同类型参数副本；不修改输入。

(import (liii check)
  (liii pi code cli args)
  (liii pi code cli args query)
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

;; 实际 CLI 使用 pi-cli-args record，而非测试用的 alist。
(let* ((original (make-pi-cli-args :messages '("a.scm")))
       (result (pi-code-review-parsed original))
      ) ;
  (check-true (string? (pi-args-ref result 'system-prompt)))
  (check (pi-args-ref original 'system-prompt) => #f)
) ;let*

(check-report)
