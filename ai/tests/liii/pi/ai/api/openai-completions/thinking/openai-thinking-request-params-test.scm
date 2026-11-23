;; openai-thinking-request-params
;; 按模型条目与思考级别生成 OpenAI Chat Completions 请求侧思考字段。
;;
;; 语法
;; ----
;; (openai-thinking-request-params model level) -> alist
;;
;; 参数
;; ----
;; model : (or alist? #f)
;; 模型目录原始条目，读取 reasoning、thinkingLevelMap 与 compat。
;; level : (or string? #f)
;; 思考级别；非字符串或 "off" 视为关闭。
;;
;; 返回值
;; ----
;; alist
;; 要合并进请求体的字段；不支持思考时不注入任何字段。

(import (liii check) (liii pi ai api openai-completions thinking))

(check-set-mode! 'report-failed)

(define DEEPSEEK
  '(("id" . "m")
    ("reasoning" . true)
    ("thinkingLevelMap"
     ("low" . "low")
     ("medium" . null)
     ("high" . "high")
     ("max" . "max"))
    ("compat" ("thinkingFormat" . "deepseek")))
) ;define

(define OPENAI
  '(("id" . "m") ("reasoning" . true) ("compat" ("thinkingFormat" . "openai")))
) ;define

(define QWEN-EFFORT
  '(("id" . "m")
    ("reasoning" . true)
    ("thinkingLevelMap"
     ("minimal" . null)
     ("low" . "low")
     ("medium" . "medium")
     ("high" . null)
     ("xhigh" . "xhigh")
     ("max" . null))
    ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . true)))
) ;define

(define QWEN-FALLBACK
  '(("id" . "m")
    ("reasoning" . true)
    ("thinkingLevelMap"
     ("minimal" . null)
     ("low" . null)
     ("medium" . null)
     ("high" . "high")
     ("xhigh" . null)
     ("max" . "max"))
    ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . true)))
) ;define

(define QWEN-NO-EFFORT
  '(("id" . "m")
    ("reasoning" . true)
    ("compat" ("thinkingFormat" . "qwen") ("supportsReasoningEffort" . false)))
) ;define

(define PLAIN '(("id" . "m") ("reasoning" . false)))

;; deepseek：开启思考并写 reasoning_effort
(check (openai-thinking-request-params DEEPSEEK "high")
  =>
  '(("thinking" ("type" . "enabled")) ("reasoning_effort" . "high"))
) ;check

;; deepseek：off 写 disabled，不写 reasoning_effort
(check (openai-thinking-request-params DEEPSEEK "off")
  =>
  '(("thinking" ("type" . "disabled")))
) ;check

;; openai：只写 reasoning_effort
(check (openai-thinking-request-params OPENAI "low")
  =>
  '(("reasoning_effort" . "low"))
) ;check

;; qwen 格式（qwen3.8 系列映射）：开启思考写 enable_thinking=true + reasoning_effort
(check (openai-thinking-request-params QWEN-EFFORT "medium")
  =>
  '(("enable_thinking" . #t) ("reasoning_effort" . "medium"))
) ;check

;; qwen 格式：映射后的 effort（xhigh→xhigh）
(check (openai-thinking-request-params QWEN-EFFORT "xhigh")
  =>
  '(("enable_thinking" . #t) ("reasoning_effort" . "xhigh"))
) ;check

;; qwen 格式：thinkingLevelMap 映射为 null 的级别回退原始级别（high→high）
(check (openai-thinking-request-params QWEN-EFFORT "high")
  =>
  '(("enable_thinking" . #t) ("reasoning_effort" . "high"))
) ;check

;; qwen 格式（deepseek/glm fallback 映射）：high→high、max→max
(check (openai-thinking-request-params QWEN-FALLBACK "high")
  =>
  '(("enable_thinking" . #t) ("reasoning_effort" . "high"))
) ;check
(check (openai-thinking-request-params QWEN-FALLBACK "max")
  =>
  '(("enable_thinking" . #t) ("reasoning_effort" . "max"))
) ;check

;; qwen 格式：off 档 enable_thinking=false 且不注入 reasoning_effort
(check (openai-thinking-request-params QWEN-EFFORT "off")
  =>
  '(("enable_thinking" . #f))
) ;check

;; qwen 格式：supportsReasoningEffort=false 时只写 enable_thinking，不写 reasoning_effort
(check (openai-thinking-request-params QWEN-NO-EFFORT "high")
  =>
  '(("enable_thinking" . #t))
) ;check
(check (openai-thinking-request-params QWEN-NO-EFFORT "off")
  =>
  '(("enable_thinking" . #f))
) ;check

;; 不支持 reasoning 的模型不注入
(check (openai-thinking-request-params PLAIN "high") => '())

;; 模型条目缺失或级别为空时不注入
(check (openai-thinking-request-params #f "high") => '())
(check (openai-thinking-request-params OPENAI #f) => '())

(check-report)
