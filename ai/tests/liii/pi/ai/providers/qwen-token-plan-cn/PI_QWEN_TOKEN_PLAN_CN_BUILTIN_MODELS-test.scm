;; PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS
;; Qwen Token Plan 团队订阅中国区内置模型元数据定义列表。
;;
;; 语法
;; ----
;; PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; list?
;; 包含各内置模型配置信息的关联列表；每条记录含 id/name/baseUrl/
;; contextWindow/maxTokens/reasoning/input/compat/thinkingLevelMap 字段。

(import (liii check) (liii pi ai providers qwen-token-plan-cn))

(check-set-mode! 'report-failed)

(check-true (pair? PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS))
(check (length PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS) => 10)

;; 模型条目辅助查表：按 id 建索引

(define (model-by-id mid)
  (let loop
    ((rest PI_QWEN_TOKEN_PLAN_CN_BUILTIN_MODELS))
    (cond ((null? rest) #f)
          ((equal? (cdr (assoc "id" (car rest))) mid) (car rest))
          (else (loop (cdr rest)))
    ) ;cond
  ) ;let
) ;define

(define (compat-ref model key)
  (let ((compat (cdr (assoc "compat" model))))
    (cdr (assoc key compat))
  ) ;let
) ;define

(define (thinking-map-ref model key)
  (let ((map (cdr (assoc "thinkingLevelMap" model))))
    (cdr (assoc key map))
  ) ;let
) ;define

;; 关键模型存在
(check-true (pair? (model-by-id "qwen4-max")))
(check-true (pair? (model-by-id "qwen3.8-max")))
(check-true (pair? (model-by-id "qwen3.8-flash")))
(check-true (pair? (model-by-id "deepseek-v4-pro")))
(check-true (pair? (model-by-id "deepseek-v4.1-flash")))
(check-true (pair? (model-by-id "deepseek-v4.1-flash-1017")))
(check-true (pair? (model-by-id "glm-5.3")))
(check-true (pair? (model-by-id "glm-5.3-prime")))
(check-true (pair? (model-by-id "glm-5.2")))
(check-true (pair? (model-by-id "kimi-k3.1-pro-prime")))

;; 不含已退役 / 当前订阅不可用 / 排除的模型
(check-false (model-by-id "qwen3.8-max-preview"))
(check-false (model-by-id "deepseek-v3.2"))
(check-false (model-by-id "deepseek-v4-flash"))
(check-false (model-by-id "qwen3.7-max"))
(check-false (model-by-id "qwen3.6-flash"))
;; 以下模型上游返回 403 AccessDenied.Unpurchased（当前团队订阅未购买），
;; 从内置目录移除
(check-false (model-by-id "MiniMax-M2.5"))
(check-false (model-by-id "glm-5"))
(check-false (model-by-id "glm-5.1"))
(check-false (model-by-id "kimi-k2.5"))
(check-false (model-by-id "kimi-k2.6"))
(check-false (model-by-id "kimi-k2.7-code"))

;; qwen3.8-max 元数据
(let ((m (model-by-id "qwen3.8-max")))
  (check (cdr (assoc "name" m)) => "Qwen3.8 Max")
  (check (cdr (assoc "baseUrl" m))
    =>
    "https://token-plan.maas.qianwenaiapi.com/compatible-mode/v1"
  ) ;check
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 131072)
  (check (cdr (assoc "reasoning" m)) => #t)
  (check (cdr (assoc "input" m)) => '("text" "image"))
  (check (compat-ref m "thinkingFormat") => "qwen")
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "medium") => "medium")
  (check (thinking-map-ref m "xhigh") => "xhigh")
  (check (thinking-map-ref m "high") => 'null)
  (check (thinking-map-ref m "max") => 'null)
) ;let

;; deepseek-v4-pro：effort fallback map
(let ((m (model-by-id "deepseek-v4-pro")))
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 384000)
  (check (cdr (assoc "input" m)) => '("text"))
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
  (check (thinking-map-ref m "low") => 'null)
) ;let

;; glm-5.2：effort fallback map
(let ((m (model-by-id "glm-5.2")))
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 131072)
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
) ;let

;; qwen4-max：对齐 qwen3.8 系列映射（effort ['low','medium','xhigh']）
(let ((m (model-by-id "qwen4-max")))
  (check (cdr (assoc "name" m)) => "Qwen4 Max")
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 262144)
  (check (cdr (assoc "reasoning" m)) => #t)
  (check (cdr (assoc "input" m)) => '("text" "image"))
  (check (compat-ref m "thinkingFormat") => "qwen")
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "medium") => "medium")
  (check (thinking-map-ref m "xhigh") => "xhigh")
  (check (thinking-map-ref m "high") => 'null)
  (check (thinking-map-ref m "max") => 'null)
) ;let

;; deepseek-v4.1-flash：effort ['low','high','max']，多模态输入
(let ((m (model-by-id "deepseek-v4.1-flash")))
  (check (cdr (assoc "name" m)) => "DeepSeek V4.1 Flash")
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 384000)
  (check (cdr (assoc "input" m)) => '("text" "image"))
  (check (compat-ref m "thinkingFormat") => "qwen")
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
  (check (thinking-map-ref m "medium") => 'null)
) ;let

;; deepseek-v4.1-flash-1017：与 deepseek-v4.1-flash 同规格（1M/384K/多模态），
;; effort ['low','high','max']，其余档位 null
(let ((m (model-by-id "deepseek-v4.1-flash-1017")))
  (check (cdr (assoc "name" m)) => "DeepSeek V4.1 Flash 1017")
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 384000)
  (check (cdr (assoc "input" m)) => '("text" "image"))
  (check (compat-ref m "thinkingFormat") => "qwen")
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
  (check (thinking-map-ref m "medium") => 'null)
) ;let

;; glm-5.3：effort ['low','high','max']（普通团队订阅可用，与 prime 同族）
(let ((m (model-by-id "glm-5.3")))
  (check (cdr (assoc "name" m)) => "GLM-5.3")
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 131072)
  (check (cdr (assoc "input" m)) => '("text"))
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
  (check (thinking-map-ref m "medium") => 'null)
) ;let

;; glm-5.3-prime：effort ['low','high','max']（需更高订阅，对齐 glm-5.3 同族）
(let ((m (model-by-id "glm-5.3-prime")))
  (check (cdr (assoc "name" m)) => "GLM-5.3 Prime")
  (check (cdr (assoc "contextWindow" m)) => 1000000)
  (check (cdr (assoc "maxTokens" m)) => 131072)
  (check (cdr (assoc "input" m)) => '("text"))
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
  (check (thinking-map-ref m "medium") => 'null)
) ;let

;; kimi-k3.1-pro-prime：effort ['low','high','max']，1M 上下文 + 多模态
(let ((m (model-by-id "kimi-k3.1-pro-prime")))
  (check (cdr (assoc "name" m)) => "Kimi K3.1 Pro Prime")
  (check (cdr (assoc "contextWindow" m)) => 1048576)
  (check (cdr (assoc "maxTokens" m)) => 32768)
  (check (cdr (assoc "input" m)) => '("text" "image"))
  (check (compat-ref m "supportsReasoningEffort") => #t)
  (check (thinking-map-ref m "low") => "low")
  (check (thinking-map-ref m "high") => "high")
  (check (thinking-map-ref m "max") => "max")
  (check (thinking-map-ref m "medium") => 'null)
) ;let

(check-report)
