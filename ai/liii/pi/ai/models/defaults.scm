;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi ai models defaults)
  (import (scheme base))
  (export PI_DEFAULT_PROVIDER pi-provider-default-model)
  (begin
    (define PI_DEFAULT_PROVIDER "deepseek")

    (define (pi-provider-default-model provider)
      (let ((p (if (symbol? provider) (symbol->string provider) provider)))
        (cond ((equal? p "all-in-one") "coding-fast")
              ((equal? p "anthropic") "claude-opus-5-5")
              ((equal? p "kimi-coding") "kimi-for-coding")
              ((equal? p "glm") "glm-5.3")
              ((equal? p "deepseek") "deepseek-flash")
              ((or (equal? p "zai-coding-cn") (equal? p "zai")) "glm-5.3")
              ((or (equal? p "minimax") (equal? p "minimax-cn")) "MiniMax-M3.1-Flash")
              ((equal? p "ollama") "qwen2.5-coder:latest")
              ((or (equal? p "opencode") (equal? p "opencode-go")) "deepseek-v4.1-flash")
              ((equal? p "qwen-token-plan-cn") "qwen3.8-max")
              (else "gemini-3.8-flash")
        ) ;cond
      ) ;let
    ) ;define
  ) ;begin
) ;define-library
