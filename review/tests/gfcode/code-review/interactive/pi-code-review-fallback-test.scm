;; pi-code-review-command fallback 路由
;; 结构化审查失败时，on-finish 经 ctx 的 fallback-runner 请求一次降级重试；
;; 无 fallback-runner（如测试环境）时原样返回错误结果。
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
;; 含 config 与 fallback-runner 的 worker 上下文。
;; prepare : procedure?（可选测试接缝）
;; 接收 parsed 和 config，返回文件收集与 prompt 数据。
;;
;; 返回值
;; ----
;; on-finish 对失败消息返回 fallback-runner 的 retry 请求；
;; 成功消息返回 status=ok 报告。
;; 降级只请求一次：fallback 结算使用统一响应解析，不再携带重试能力。

(import (scheme base)
  (liii check)
  (liii string)
  (liii pi ai message)
  (gfcode code-review interactive)
) ;import

(check-set-mode! 'report-failed)

(define (error-msgs)
  (list (pi-assistant-message '() :stop-reason "error" :error-message "provider down")
  ) ;list
) ;define

(define (ok-msgs)
  (list (pi-assistant-message (list (pi-text-block "{\"findings\":[]}"))
          :stop-reason "stop"
        ) ;pi-assistant-message
  ) ;list
) ;define

(let* ((retried #f)
       (request
         (pi-code-review-command "a.scm"
           (list (cons 'config '())
             (cons 'fallback-runner
               (lambda (prompt on-finish)
                 (set! retried (list prompt on-finish))
                 (list (cons 'status 'retry) (cons 'prompt prompt) (cons 'on-finish on-finish))
               ) ;lambda
             ) ;cons
           ) ;list
           :prepare
           (lambda (parsed cfg)
             (list (cons 'status 'ok)
               (cons 'prompt "structured")
               (cons 'records
                 (list (list (cons 'path "a.scm") (cons 'language "scheme") (cons 'content "x")))
               ) ;cons
             ) ;list
           ) ;lambda
         ) ;pi-code-review-command
       ) ;request
       (on-finish (cdr (assoc 'on-finish request)))
      ) ;
  ;; 成功：不触发 fallback
  (check
    (cdr (assoc 'status (on-finish (ok-msgs))))
    =>
    'ok
  ) ;check
  (check retried => #f)
  ;; 失败：请求一次降级，prompt 为只读 fallback 提示词
  (let ((retry (on-finish (error-msgs))))
    (check (cdr (assoc 'status retry)) => 'retry)
    (check-true (string-contains? (cdr (assoc 'prompt retry)) "Do not modify any file")
    ) ;check-true
    (check-true (procedure? (cdr (assoc 'on-finish retry))))
    ;; 降级结算：统一响应解析，不再产生 retry
    (check
      (cdr
        (assoc 'status ((cdr (assoc 'on-finish retry)) (ok-msgs)))
      ) ;cdr
      =>
      'ok
    ) ;check
    (check
      (cdr
        (assoc 'status ((cdr (assoc 'on-finish retry)) (error-msgs)))
      ) ;cdr
      =>
      'error
    ) ;check
  ) ;let
) ;let*

;; 无 fallback-runner：失败原样返回错误
(let* ((request
         (pi-code-review-command "a.scm"
           '((config))
           :prepare
           (lambda (parsed cfg)
             (list (cons 'status 'ok) (cons 'prompt "p") (cons 'records '()))
           ) ;lambda
         ) ;pi-code-review-command
       ) ;request
      ) ;
  (check
    (cdr
      (assoc 'status ((cdr (assoc 'on-finish request)) (error-msgs)))
    ) ;cdr
    =>
    'error
  ) ;check
) ;let*

(check-report)
