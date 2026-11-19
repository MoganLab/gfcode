;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 思考级别与模型元数据查询：按 models-store 目录条目判断模型能力。
(define-library (liii pi code config thinking)
  (import (scheme base)
    (liii pi ai models)
    (liii pi ai thinking)
    (liii pi code config settings)
  ) ;import
  (export %model-supports-thinking? pi-model-supports-thinking?
    pi-model-available-thinking-levels
  ) ;export
  (begin

    ;; 从 models-store 原始条目查询模型是否支持 reasoning；
    ;; 元数据缺失时默认支持（对齐上游：无模型信息时返回全集级别）。
    ;; JSON 布尔为符号 true/false，必须归一化后再判真假，
    ;; 否则 reasoning: false 会被当成真值。
    (define (%model-supports-thinking? models-store provider model-id)
      (let ((model
              (find (lambda (entry) (equal? (json-dict-ref entry "id" #f) model-id))
                (pi-catalog-provider-models models-store provider)
              ) ;find
            ) ;model
           ) ;
        (if model (pi-model-supports-reasoning? model) #t)
      ) ;let
    ) ;define

    ;; 公开包装：/model 切换后重算 supports-thinking（worker 与 TUI 共用）
    (define (pi-model-supports-thinking? models-store provider model-id)
      (%model-supports-thinking? models-store provider model-id)
    ) ;define

    ;; 模型可用思考级别集（对齐上游 getSupportedThinkingLevels）：
    ;; 目录条目缺失时返回全集（对齐上游：无模型信息时返回全集级别）
    (define (pi-model-available-thinking-levels models-store provider model-id)
      (let ((model
              (find (lambda (entry) (equal? (json-dict-ref entry "id" #f) model-id))
                (pi-catalog-provider-models models-store provider)
              ) ;find
            ) ;model
           ) ;
        (if model (pi-model-thinking-levels model) pi-thinking-levels)
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
