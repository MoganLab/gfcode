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
(check-true (pair? (model-by-id "qwen3.8-max")))
(check-true (pair? (model-by-id "qwen3.8-flash")))
(check-true (pair? (model-by-id "deepseek-v4-pro")))
(check-true (pair? (model-by-id "glm-5.2")))
(check-true (pair? (model-by-id "kimi-k2.7-code")))
(check-true (pair? (model-by-id "MiniMax-M2.5")))

;; 不含已退役 / 排除的模型
(check-false (model-by-id "qwen3.8-max-preview"))
(check-false (model-by-id "deepseek-v3.2"))
(check-false (model-by-id "deepseek-v4-flash"))
(check-false (model-by-id "qwen3.7-max"))
(check-false (model-by-id "qwen3.6-flash"))

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

;; MiniMax-M2.5：无 thinkingLevelMap、supportsReasoningEffort=#f
(let ((m (model-by-id "MiniMax-M2.5")))
  (check (cdr (assoc "contextWindow" m)) => 196608)
  (check (cdr (assoc "maxTokens" m)) => 32768)
  (check (cdr (assoc "input" m)) => '("text"))
  (check (compat-ref m "thinkingFormat") => "qwen")
  (check (compat-ref m "supportsReasoningEffort") => #f)
  (check-false (assoc "thinkingLevelMap" m))
) ;let

;; kimi-k2.7-code：无 thinkingLevelMap、supportsReasoningEffort=#f
(let ((m (model-by-id "kimi-k2.7-code")))
  (check (cdr (assoc "input" m)) => '("text" "image"))
  (check (compat-ref m "supportsReasoningEffort") => #f)
  (check-false (assoc "thinkingLevelMap" m))
) ;let

(check-report)
