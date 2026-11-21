;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OpenAI Responses API 请求侧思考参数：
;; - 从 models-store 取原始模型条目
;; - 按 thinkingFormat 生成 reasoning 参数（Responses 用 reasoning.effort + summary）
;; 当前覆盖 openai 风格；其他格式保持不注入，避免猜错字段。
(define-library (liii pi ai api openai-responses thinking)
  (import (scheme base) (liii string) (liii list))
  (export responses-resolve-model-entry responses-thinking-request-params)
  (begin

    (define (%val key obj default-val)
      (if (not (pair? obj))
        default-val
        (let ((p
                (or (assoc key obj)
                  (assoc (if (symbol? key) (symbol->string key) (string->symbol key)) obj)
                ) ;or
              ) ;p
             ) ;
          (if (pair? p) (cdr p) default-val)
        ) ;let
      ) ;if
    ) ;define

    (define (%json-true? v)
      (or (eq? v #t) (eq? v 'true))
    ) ;define

    (define (%model-supports-reasoning? model)
      (and (pair? model) (%json-true? (%val "reasoning" model #f)))
    ) ;define

    (define (%compat-ref model key default-val)
      (let ((compat (%val "compat" model #f)))
        (if (pair? compat) (%val key compat default-val) default-val)
      ) ;let
    ) ;define

    (define (%thinking-off? level)
      (or (not (string? level)) (string=? (string-trim-both level) "off"))
    ) ;define

    (define (%find-model-entry models model-id)
      (let loop
        ((rest (cond ((vector? models) (vector->list models))
                     ((list? models) models)
                     (else '())
               ) ;cond
         ) ;rest
        ) ;
        (cond ((null? rest) #f)
              ((equal? (%val "id" (car rest) #f) model-id) (car rest))
              (else (loop (cdr rest)))
        ) ;cond
      ) ;let
    ) ;define

    (define (responses-resolve-model-entry models-store provider model-id)
      (let ((p-entry (and provider (%val provider models-store #f))))
        (and (pair? p-entry)
          (string? model-id)
          (%find-model-entry (%val "models" p-entry '()) model-id)
        ) ;and
      ) ;let
    ) ;define

    (define (%mapped-effort model level)
      (let* ((map (%val "thinkingLevelMap" model '()))
             (mapped (and (pair? map) (%val level map #f)))
            ) ;
        (if (string? mapped) mapped level)
      ) ;let*
    ) ;define

    ;; Responses API 思考参数：reasoning.effort + reasoning.summary。
    ;; summary="auto" 让推理摘要以 reasoning_text 流式返回（与内部 thinking 块对齐）。
    ;; off 档：Responses 没有关闭推理的开关，只能降档到最低支持值。这里用 "low"
    ;; 而不是 "minimal"：部分模型（如 gpt-6.2-sol）会以 unsupported_value 拒绝
    ;; "minimal"，而 "low" 在常见 Responses 模型上均被接受。
    (define (%responses-thinking-params model level)
      (if (%thinking-off? level)
        (if (%compat-ref model "supportsReasoningEffort" #t)
          (list (cons "reasoning" (list (cons "effort" "low") (cons "summary" "none"))))
          '()
        ) ;if
        (if (%compat-ref model "supportsReasoningEffort" #t)
          (list
            (cons "reasoning"
              (list (cons "effort" (%mapped-effort model level)) (cons "summary" "auto"))
            ) ;cons
          ) ;list
          (list (cons "reasoning" (list (cons "summary" "auto"))))
        ) ;if
      ) ;if
    ) ;define

    ;; 仅注入已实现且显式声明的格式；未知格式保持原行为（不猜字段）。
    (define (responses-thinking-request-params model level)
      (if (not (%model-supports-reasoning? model))
        '()
        (let ((format (%compat-ref model "thinkingFormat" "openai")))
          (cond ((equal? format "openai") (%responses-thinking-params model level))
                (else '())
          ) ;cond
        ) ;let
      ) ;if
    ) ;define

  ) ;begin
) ;define-library
