;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 阿里云百炼 QwenCloud Token Plan 团队订阅（中国区）
;;
;; - 端点：https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1
;;   （对齐上游 pi qwenTokenPlanCnProvider 的 baseUrl）
;; - 协议：openai-completions（OpenAI Chat Completions 兼容）
;; - env 角色对齐上游 env-api-keys.ts：
;;     团队订阅变量 QWEN_TOKEN_PLAN_TEAM_CN_API_KEY 优先，回退区域共享变量
;;     QWEN_TOKEN_PLAN_CN_API_KEY
;; - 思考格式为 qwen：注入 enable_thinking（布尔）+ 可选 reasoning_effort
;; - 内置模型清单为上游 qwen-token-plan-models.test.ts 固定的团队版 TEXT_MODELS
;;   快照（仅保留 qwen3.8 系列，不含已退役模型）
;; - 额度耗尽识别：上游未注册专门 quota handler，初版同样不识别，429 仍按可
;;   重试处理（待拿到真实 429 业务码后再补码表）

(define-library (liii pi ai providers qwen-token-plan-cn)
  (import (scheme base) (liii pi ai providers quota))
  (export PI_QWEN_TOKEN_PLAN_CN_PROVIDER PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS
    PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR
  ) ;export
  (begin

    ;; 端点（对齐上游 qwenTokenPlanCnProvider 的 baseUrl）
    (define %base-url
      "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1"
    ) ;define

    ;; qwen 思考格式兼容标记：所有模型统一 thinkingFormat=qwen；
    ;; supportsReasoningEffort 决定是否注入 reasoning_effort。
    (define (%qwen-compat supports-effort)
      (list (cons "thinkingFormat" "qwen")
        (cons "supportsReasoningEffort" supports-effort)
      ) ;list
    ) ;define

    ;; deepseek-v4-pro / glm-5 / glm-5.1 / glm-5.2 的 thinkingLevelMap：
    ;; 仅 high→high、max→max，其余映射为 null（不支持该档）
    (define %effort-fallback-map
      '(("minimal" . null)
        ("low" . null)
        ("medium" . null)
        ("high" . "high")
        ("xhigh" . null)
        ("max" . "max"))
    ) ;define

    ;; qwen3.8 系列的 thinkingLevelMap：low→low、medium→medium、xhigh→xhigh，
    ;; high 与 max 映射为 null（不支持该档）
    (define %qwen38-map
      '(("minimal" . null)
        ("low" . "low")
        ("medium" . "medium")
        ("high" . null)
        ("xhigh" . "xhigh")
        ("max" . null))
    ) ;define

    ;; Provider 配置：api 为协议实现标识（OpenAI Chat Completions 兼容），
    ;; baseUrl 为中国区端点，envKeys 为依次尝试的 API key 环境变量
    ;; （团队订阅变量优先，回退区域共享变量，对齐上游 env-api-keys.ts 的角色）
    (define PI_QWEN_TOKEN_PLAN_CN_PROVIDER
      '((api . "openai-completions")
        (baseUrl . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
        (envKeys "QWEN_TOKEN_PLAN_TEAM_CN_API_KEY" "QWEN_TOKEN_PLAN_CN_API_KEY"))
    ) ;define

    ;; 内置模型目录：团队订阅中国区 TEXT_MODELS 快照（仅保留 qwen3.8 系列）。
    ;; 每条记录含 id/name/baseUrl/contextWindow/maxTokens/reasoning/input/compat
    ;; /thinkingLevelMap 字段，供 openai-thinking-request-params 取思考格式与映射。
    (define PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS
      '((("id" . "MiniMax-M2.5")
         ("name" . "MiniMax-M2.5")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 196608)
         ("maxTokens" . 32768)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #f)))
        (("id" . "deepseek-v4-pro")
         ("name" . "DeepSeek V4 Pro")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 384000)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
           ("minimal" . null)
           ("low" . null)
           ("medium" . null)
           ("high" . "high")
           ("xhigh" . null)
           ("max" . "max")))
        (("id" . "glm-5")
         ("name" . "GLM-5")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 202752)
         ("maxTokens" . 16384)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
           ("minimal" . null)
           ("low" . null)
           ("medium" . null)
           ("high" . "high")
           ("xhigh" . null)
           ("max" . "max")))
        (("id" . "glm-5.1")
         ("name" . "GLM-5.1")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 202752)
         ("maxTokens" . 128000)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
           ("minimal" . null)
           ("low" . null)
           ("medium" . null)
           ("high" . "high")
           ("xhigh" . null)
           ("max" . "max")))
        (("id" . "glm-5.2")
         ("name" . "GLM-5.2")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 131072)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
           ("minimal" . null)
           ("low" . null)
           ("medium" . null)
           ("high" . "high")
           ("xhigh" . null)
           ("max" . "max")))
        (("id" . "kimi-k2.5")
         ("name" . "Kimi K2.5")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 262144)
         ("maxTokens" . 98304)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #f)))
        (("id" . "kimi-k2.6")
         ("name" . "Kimi K2.6")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 262144)
         ("maxTokens" . 262144)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #f)))
        (("id" . "kimi-k2.7-code")
         ("name" . "Kimi K2.7 Code")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 262144)
         ("maxTokens" . 262144)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #f)))
        (("id" . "qwen3.8-flash")
         ("name" . "Qwen3.8 Flash")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 131072)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
           ("minimal" . null)
           ("low" . "low")
           ("medium" . "medium")
           ("high" . null)
           ("xhigh" . "xhigh")
           ("max" . null)))
        (("id" . "qwen3.8-max")
         ("name" . "Qwen3.8 Max")
         ("baseUrl" . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 131072)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
           ("minimal" . null)
           ("low" . "low")
           ("medium" . "medium")
           ("high" . null)
           ("xhigh" . "xhigh")
           ("max" . null))))
    ) ;define

    ;; 「额度耗尽」识别：
    ;; 上游 src/providers/qwen-token-plan-cn.ts 未注册专门 quota handler，
    ;; 本任务初版同样不识别，429 仍按可重试处理。
    ;; TODO: 待拿到该端点真实 429 业务码后再补码表，避免凭空猜测误杀瞬时限流。
    (define (PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR status-code body-str)
      #f
    ) ;define

  ) ;begin
) ;define-library
