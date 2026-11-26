;; pi-code-review-response
;; 将 Agent 最终消息转换为统一的审查成功报告或可读错误。
;;
;; 语法
;; ----
;; (pi-code-review-response messages)
;;
;; 参数
;; ----
;; messages : list?
;; Agent 最终消息列表。
;;
;; 返回值
;; ----
;; alist
;; 成功时含 status=ok 与 report；模型失败或截断时含 status=error 与 message。
;;
;; 错误行为
;; --------
;; error、aborted 和 length 不生成 findings；非法 JSON 由解析器生成 parse-error finding。

(import (liii check)
  (liii string)
  (liii pi ai message)
  (gfcode code-review response)
) ;import

(check-set-mode! 'report-failed)

(let ((result
        (pi-code-review-response
          (list (pi-assistant-message (list (pi-text-block "{\"findings\":[]}"))
                  :stop-reason "stop"
                ) ;pi-assistant-message
          ) ;list
        ) ;pi-code-review-response
      ) ;result
     ) ;
  (check (cdr (assoc 'status result)) => 'ok)
  (check-true (string-contains? (cdr (assoc 'report result)) "no issues"))
) ;let

(let ((result (pi-code-review-response (list (pi-assistant-message '() :stop-reason "error" :error-message "request failed")
                                       ) ;list
              ) ;pi-code-review-response
      ) ;result
     ) ;
  (check (cdr (assoc 'status result)) => 'error)
  (check (cdr (assoc 'message result)) => "request failed")
) ;let

(let ((result (pi-code-review-response (list (pi-assistant-message '() :stop-reason "length"))
              ) ;pi-code-review-response
      ) ;result
     ) ;
  (check (cdr (assoc 'status result)) => 'error)
  (check-true (string-contains? (cdr (assoc 'message result)) "truncated"))
) ;let

(check-report)
