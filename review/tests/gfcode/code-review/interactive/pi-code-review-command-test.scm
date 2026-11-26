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
;; alist
;; 参数错误返回 status=error；无变更返回 status=no-files；
;; 成功时追加 parsed、config、prompt、on-finish 供通用 worker 执行。
;; 未知参数不抛异常，以可读错误结果返回。

(import (liii check) (liii string) (gfcode code-review interactive))

(check-set-mode! 'report-failed)

(let* ((seen #f)
       (result
         (pi-code-review-command "--staged --ref=main a.scm"
           (list
             (cons 'config (list (cons 'tools '("write")) (cons 'provider "google")))
           ) ;list
           :prepare
           (lambda (parsed cfg)
             (set! seen parsed)
             (list (cons 'status 'ok) (cons 'prompt "review") (cons 'notice #f))
           ) ;lambda
         ) ;pi-code-review-command
       ) ;result
      ) ;
  (check (cdr (assoc 'status result)) => 'ok)
  (check (cdr (assoc 'prompt result)) => "review")
  (check (procedure? (cdr (assoc 'on-finish result))) => #t)
  (check
    (cdr (assoc 'tools (cdr (assoc 'config result))))
    =>
    '()
  ) ;check
  (check (cdr (assoc 'messages seen)) => '("a.scm"))
  (check (cdr (assoc 'review-ref seen)) => "main")
  (check (cdr (assoc 'staged seen)) => #t)
  (check (cdr (assoc 'code-review seen)) => #t)
  (check (cdr (assoc 'no-skills seen)) => #t)
) ;let*

(check (cdr (assoc 'status (pi-code-review-command "--bad" '()))) => 'error)

(let ((result
        (pi-code-review-command ""
          '()
          :prepare (lambda (parsed cfg) (list (cons 'status 'no-files)))
        ) ;pi-code-review-command
      ) ;result
     ) ;
  (check (cdr (assoc 'status result)) => 'no-files)
  (check-true (string? (cdr (assoc 'message result))))
) ;let

(check-report)
