;; pi-code-review-command
;; 将交互命令参数转换为通用 worker 可执行的只读 session 请求。
;;
;; 语法
;; ----
;; (pi-code-review-command args ctx :prepare prepare)
;;
;; 参数
;; ----
;; args : string?
;; `/review` 后的原始参数。
;; ctx : alist?
;; 含 config 的 worker 上下文。
;; prepare : procedure?（可选测试接缝）
;; 接收 parsed 和 config，返回文件收集与 prompt 数据。
;;
;; 返回值
;; ----
;; review-result
;; 参数错误返回 review-error；无变更返回 review-no-files；
;; 成功时返回 review-session-request，含 parsed、config、prompt、on-finish 供通用 worker 执行。
;; 未知参数不抛异常，以可读错误结果返回。

(import (liii check)
  (liii string)
  (gfcode code-review interactive)
  (gfcode code-review result)
) ;import

(check-set-mode! 'report-failed)

(let* ((seen #f)
       (result
         (pi-code-review-command "--staged --ref=main a.scm"
           (list
             (cons 'config (list (cons 'tools '("bash" "read")) (cons 'provider "google")))
           ) ;list
           :prepare
           (lambda (parsed cfg)
             (set! seen parsed)
             (make-review-session-request #f #f "review" #f #f #f '() '())
           ) ;lambda
         ) ;pi-code-review-command
       ) ;result
      ) ;
  (check (review-session-request? result) => #t)
  (check (review-session-request-prompt result) => "review")
  (check (procedure? (review-session-request-on-finish result)) => #t)
  (check (cdr (assoc 'tools (review-session-request-config result)))
    =>
    '("bash" "read")
  ) ;check
  (check (cdr (assoc 'messages seen)) => '("a.scm"))
  (check (cdr (assoc 'review-ref seen)) => "main")
  (check (cdr (assoc 'staged seen)) => #t)
  (check (cdr (assoc 'code-review seen)) => #t)
  (check (cdr (assoc 'no-skills seen)) => #t)
) ;let*

(check (review-error? (pi-code-review-command "--bad" '())) => #t)

(let ((result (pi-code-review-command ""
                '()
                :prepare (lambda (parsed cfg) (make-review-no-files #f #f))
              ) ;pi-code-review-command
      ) ;result
     ) ;
  (check (review-no-files? result) => #t)
  (check-true (string? (review-no-files-message result)))
) ;let

(check-report)
