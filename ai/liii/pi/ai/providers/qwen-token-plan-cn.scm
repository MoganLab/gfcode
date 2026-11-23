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
;; - 内置模型清单以上游 qwen-token-plan-models.test.ts 固定的团队版 TEXT_MODELS
;;   快照为基础（仅保留 qwen3.8 系列，不含已退役模型），并补充阿里云百炼新上线
;;   的 qwen4-max / deepseek-v4.1-flash / glm-5.3-prime / kimi-k3.1-pro-prime
;;   （models.dev 尚未收录前三者，其 reasoning effort 与上下文规格对齐同族基线）
;; - 额度耗尽识别：上游未注册专门 quota handler，初版同样不识别，429 仍按可
;;   重试处理（待拿到真实 429 业务码后再补码表）

(define-library (liii pi ai providers qwen-token-plan-cn)
  (import (scheme base))
  (export PI_QWEN_TOKEN_PLAN_CN_PROVIDER
    PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS
    PI_QWEN_TOKEN_PLAN_CN_QUOTA_ERROR
  ) ;export
  (begin

    ;; Provider 配置：api 为协议实现标识（OpenAI Chat Completions 兼容），
    ;; baseUrl 为中国区端点，envKeys 为依次尝试的 API key 环境变量
    ;; （团队订阅变量优先，回退区域共享变量，对齐上游 env-api-keys.ts 的角色）
    (define PI_QWEN_TOKEN_PLAN_CN_PROVIDER
      '((api . "openai-completions")
        (baseUrl
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
        (envKeys "QWEN_TOKEN_PLAN_TEAM_CN_API_KEY" "QWEN_TOKEN_PLAN_CN_API_KEY"))
    ) ;define

    ;; 内置模型目录：团队订阅中国区 TEXT_MODELS 快照（仅保留 qwen3.8 系列）。
    ;; 每条记录含 id/name/baseUrl/contextWindow/maxTokens/reasoning/input/compat
    ;; /thinkingLevelMap 字段，供 openai-thinking-request-params 取思考格式与映射。
    (define PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS
      '((("id" . "deepseek-v4-pro")
         ("name" . "DeepSeek V4 Pro")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
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
        ;; 阿里云百炼新上线：DeepSeek V4.1 Flash（对齐 models.dev
        ;; alibaba-token-plan-cn 的 reasoning effort ['low','high','max'] 与上下文规格）
        (("id" . "deepseek-v4.1-flash")
         ("name" . "DeepSeek V4.1 Flash")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 384000)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
          ("minimal" . null)
          ("low" . "low")
          ("medium" . null)
          ("high" . "high")
          ("xhigh" . null)
          ("max" . "max")))
        ;; 阿里云百炼新版快照：DeepSeek V4.1 Flash 1017（与 deepseek-v4.1-flash
        ;; 同规格：1M 上下文 / 384K maxTokens / 多模态，reasoning effort
        ;; ['low','high','max']，其余档位映射为 null）
        (("id" . "deepseek-v4.1-flash-1017")
         ("name" . "DeepSeek V4.1 Flash 1017")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 384000)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
          ("minimal" . null)
          ("low" . "low")
          ("medium" . null)
          ("high" . "high")
          ("xhigh" . null)
          ("max" . "max")))
        (("id" . "glm-5.2")
         ("name" . "GLM-5.2")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
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
        ;; 阿里云百炼上线：GLM-5.3（普通团队订阅可用，reasoning effort 对齐
        ;; 同族 ['low','high','max']，上下文 1M / maxTokens 131072）
        (("id" . "glm-5.3")
         ("name" . "GLM-5.3")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 131072)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
          ("minimal" . null)
          ("low" . "low")
          ("medium" . null)
          ("high" . "high")
          ("xhigh" . null)
          ("max" . "max")))
        ;; 阿里云百炼新上线：GLM-5.3 Prime（Prime 通道，需更高订阅，reasoning effort
        ;; 对齐同族 glm-5.3 的 ['low','high','max']，上下文规格沿用 glm-5.3）
        (("id" . "glm-5.3-prime")
         ("name" . "GLM-5.3 Prime")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 131072)
         ("reasoning" . #t)
         ("input" "text")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
          ("minimal" . null)
          ("low" . "low")
          ("medium" . null)
          ("high" . "high")
          ("xhigh" . null)
          ("max" . "max")))
        ;; 阿里云百炼新上线：Kimi K3.1 Pro Prime（Prime 通道，always-on 思考；
        ;; reasoning effort ['low','high','max']，1M 上下文 + 多模态输入）
        (("id" . "kimi-k3.1-pro-prime")
         ("name" . "Kimi K3.1 Pro Prime")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1048576)
         ("maxTokens" . 32768)
         ("reasoning" . #t)
         ("input" "text" "image")
         ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . #t))
         ("thinkingLevelMap"
          ("minimal" . null)
          ("low" . "low")
          ("medium" . null)
          ("high" . "high")
          ("xhigh" . null)
          ("max" . "max")))
        (("id" . "qwen3.8-flash")
         ("name" . "Qwen3.8 Flash")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
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
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
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
        ;; 阿里云百炼新上线：Qwen4 Max 旗舰（qwen4-max-preview 的正式版，
        ;; reasoning effort ['low','medium','xhigh']，对齐 qwen3.8 系列映射）
        (("id" . "qwen4-max")
         ("name" . "Qwen4 Max")
         ("baseUrl"
          . "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1")
         ("contextWindow" . 1000000)
         ("maxTokens" . 262144)
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
