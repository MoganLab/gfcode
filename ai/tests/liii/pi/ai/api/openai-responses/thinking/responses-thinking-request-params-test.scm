;; responses-thinking-request-params
;; Responses 请求侧思考参数：reasoning.effort + reasoning.summary。
;;
;; 语法
;; ----
;; (responses-thinking-request-params model level)
;;
;; 参数
;; ----
;; model : alist | #f
;; models-store 中的原始模型条目（含 reasoning / compat / thinkingLevelMap）。
;; level : string | #f
;; 思考级别（off/minimal/low/medium/high/xhigh/max）。
;;
;; 返回值
;; ----
;; list
;; 请求体片段：((\"reasoning\" (\"effort\" . ...) (\"summary\" . ...)) ...)；不注入时为空表。

(import (liii check) (liii pi ai api openai-responses thinking))

(check-set-mode! 'report-failed)

(define (reasoning-of params)
  (let ((pair (assoc "reasoning" params)))
    (if pair (cdr pair) #f)
  ) ;let
) ;define

;; 推理模型 + 受支持级别：effort 取映射值，summary=auto（让推理摘要流式返回）
(let* ((model '(("id" . "gpt-6.2-sol") ("reasoning" . #t)))
       (params (responses-thinking-request-params model "high"))
       (r (reasoning-of params))
      ) ;
  (check (cdr (assoc "effort" r)) => "high")
  (check (cdr (assoc "summary" r)) => "auto")
) ;let*

;; xhigh / max 原样透传（gpt-6.2-sol 仅这两档产生推理内容）
(check
  (cdr
    (assoc "effort"
      (reasoning-of (responses-thinking-request-params '(("reasoning" . #t)) "xhigh"))
    ) ;assoc
  ) ;cdr
  =>
  "xhigh"
) ;check
(check
  (cdr
    (assoc "effort"
      (reasoning-of (responses-thinking-request-params '(("reasoning" . #t)) "max"))
    ) ;assoc
  ) ;cdr
  =>
  "max"
) ;check

;; off 档降为 low（不用 minimal：部分模型以 unsupported_value 拒绝 minimal），summary=none
(let* ((model '(("reasoning" . #t)))
       (r (reasoning-of (responses-thinking-request-params model "off")))
      ) ;
  (check (cdr (assoc "effort" r)) => "low")
  (check (cdr (assoc "summary" r)) => "none")
) ;let*

;; thinkingLevelMap 映射：配置的映射值优先
(let* ((model '(("reasoning" . #t) ("thinkingLevelMap" ("high" . "xhigh"))))
       (r (reasoning-of (responses-thinking-request-params model "high")))
      ) ;
  (check (cdr (assoc "effort" r)) => "xhigh")
) ;let*

;; 非推理模型：不注入 reasoning
(check (responses-thinking-request-params '(("reasoning" . #f)) "high") => '())
(check (responses-thinking-request-params #f "high") => '())

;; compat.supportsReasoningEffort=false：只发 summary，不发 effort
(let* ((model '(("reasoning" . #t) ("compat" ("supportsReasoningEffort" . #f))))
       (r (reasoning-of (responses-thinking-request-params model "high")))
      ) ;
  (check (assoc "effort" r) => #f)
  (check (cdr (assoc "summary" r)) => "auto")
) ;let*

;; 未知 thinkingFormat：保守不注入
(check
  (responses-thinking-request-params '(("reasoning" . #t)
                                       ("compat" ("thinkingFormat" . "unknown")))
    "high"
  ) ;responses-thinking-request-params
  =>
  '()
) ;check

;; responses-resolve-model-entry：按 provider/model 取原始条目
(let* ((store '(("p" ("models" . #((("id" . "m1") ("reasoning" . #t)))))))
       (entry (responses-resolve-model-entry store "p" "m1"))
      ) ;
  (check (pair? entry) => #t)
  (check (cdr (assoc "reasoning" entry)) => #t)
  (check (responses-resolve-model-entry store "p" "missing") => #f)
) ;let*

(check-report)
