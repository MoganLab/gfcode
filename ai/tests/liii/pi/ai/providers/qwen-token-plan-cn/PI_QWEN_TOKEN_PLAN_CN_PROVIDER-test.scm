;; PI_QWEN_TOKEN_PLAN_CN_PROVIDER
;; Qwen Token Plan 团队订阅中国区服务商基础配置定义。
;;
;; 语法
;; ----
;; PI_QWEN_TOKEN_PLAN_CN_PROVIDER
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; list?
;; 包含 api 协议、baseUrl 与 envKeys 环境变量列表的关联列表。

(import (liii check) (liii pi ai providers qwen-token-plan-cn))

(check-set-mode! 'report-failed)

(check-true (pair? PI_QWEN_TOKEN_PLAN_CN_PROVIDER))
(check (cdr (assoc 'api PI_QWEN_TOKEN_PLAN_CN_PROVIDER))
  =>
  "openai-completions"
) ;check
(check (cdr (assoc 'baseUrl PI_QWEN_TOKEN_PLAN_CN_PROVIDER))
  =>
  "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1"
) ;check
(check (cdr (assoc 'envKeys PI_QWEN_TOKEN_PLAN_CN_PROVIDER))
  =>
  '("QWEN_TOKEN_PLAN_TEAM_CN_API_KEY" "QWEN_TOKEN_PLAN_CN_API_KEY")
) ;check

(check-report)
