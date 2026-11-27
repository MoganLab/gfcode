;; PI_DEEPSEEK_BUILTIN_MODELS
;; DeepSeek 内置模型元数据定义列表。
;;
;; 语法
;; ----
;; PI_DEEPSEEK_BUILTIN_MODELS
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; list?
;; 包含各内置模型配置信息的关联列表。

(import (liii check)
  (liii list)
  (liii pi ai thinking)
  (liii pi ai providers deepseek)
) ;import

(check-set-mode! 'report-failed)

(check-true (pair? PI_DEEPSEEK_BUILTIN_MODELS))
(let* ((model
         (find
           (lambda (m) (equal? (cdr (assoc "id" m)) "deepseek-flash"))
           PI_DEEPSEEK_BUILTIN_MODELS
         ) ;find
       ) ;model
       (field (lambda (key) (cdr (assoc key model))))
       (compat (field "compat"))
      ) ;
  (check (field "name") => "DeepSeek V4.1 Flash")
  (check (field "api") => "openai-completions")
  (check (field "baseUrl") => "https://api.deepseek.com")
  (check (field "reasoning") => #t)
  (check (field "input") => '("text" "image"))
  (check (field "contextWindow") => 1000000)
  (check (field "maxTokens") => 384000)
  (check (pi-model-thinking-levels model) => '("off" "low" "high" "max"))
  (check (field "thinkingLevelMap")
    =>
    '(("minimal" . null)
      ("low" . "low")
      ("medium" . null)
      ("high" . "high")
      ("max" . "max"))
  ) ;check
  (check (cdr (assoc "thinkingFormat" compat)) => "deepseek")
  (check (cdr (assoc "requiresReasoningContentOnAssistantMessages" compat)) => #t)
) ;let*

(check-report)
