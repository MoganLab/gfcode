;; PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR
;; Qwen Token Plan 团队订阅中国区的额度耗尽识别函数。
;;
;; 语法
;; ----
;; (PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR status-code body-str)
;;
;; 参数
;; ----
;; status-code : integer?
;; HTTP 状态码。
;;
;; body-str : string?
;; 响应体原文。
;;
;; 返回值
;; ----
;; pi-quota-limit? 或 #f
;; 初版为占位实现：上游未注册专门 quota handler，本函数始终返回 #f，
;; 429 仍按可重试处理；待拿到真实 429 业务码后再补码表。

(import (liii check) (liii pi ai providers qwen-token-plan-cn))

(check-set-mode! 'report-failed)

;; 初版占位：任何状态码与响应体均返回 #f，不判定额度耗尽
(check-false (PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR 429
               "{\"error\":{\"code\":\"quota_exceeded\",\"message\":\"limit reached\"}}"
             ) ;PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR
) ;check-false

(check-false (PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR 403
               "{\"error\":{\"type\":\"rate_limit_error\"}}"
             ) ;PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR
) ;check-false

;; 非 {403,429} 状态码同样返回 #f
(check-false (PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR 400 "anything"))

;; 空体
(check-false (PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR 429 ""))

(check-report)
