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
;; review-result
;; 成功时为 review-ok（含 report）；模型失败或截断时为 review-error（含 message）。
;;
;; error、aborted 和 length 不生成 findings；非法 JSON 由解析器生成 parse-error finding。

(import (liii check)
  (liii string)
  (liii pi ai message)
  (gfcode code-review response)
  (gfcode code-review result)
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
  (check (review-ok? result) => #t)
  (check-true (string-contains? (review-ok-report result) "no issues"))
) ;let

(let ((result (pi-code-review-response (list (pi-assistant-message '() :stop-reason "error" :error-message "request failed")
                                       ) ;list
              ) ;pi-code-review-response
      ) ;result
     ) ;
  (check (review-error? result) => #t)
  (check (review-error-message result) => "request failed")
) ;let

(let ((result (pi-code-review-response (list (pi-assistant-message '() :stop-reason "length"))
              ) ;pi-code-review-response
      ) ;result
     ) ;
  (check (review-error? result) => #t)
  (check-true (string-contains? (review-error-message result) "truncated"))
) ;let

(check-report)
