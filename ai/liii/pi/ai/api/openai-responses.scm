;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OpenAI Responses API（POST /v1/responses）协议聚合层。
;; 与 openai-completions 平行：子模块按职责拆分，本库仅做导出汇总。
(define-library (liii pi ai api openai-responses)
  (import (scheme base)
    (liii pi ai api openai-responses core)
    (liii pi ai api openai-responses msg)
    (liii pi ai api openai-responses stream-parse)
    (liii pi ai api openai-responses request)
    (liii pi ai api openai-responses stream)
  ) ;import
  (export responses-map-stop-reason responses-map-usage responses-parse-response
    responses-is-retriable-error? responses-build-tool-declarations
    responses-build-messages responses-build-request-body
    append-responses-stream-text process-responses-tool-call-delta
    finish-responses-stream process-responses-chunk
    make-responses-stream-decoder extract-responses-stream-error-message
    responses-build-tool-declarations-from-names responses-request
    responses-build-endpoint responses-build-headers responses-build-proxy-alist
    responses-request-stream responses-resolve-prompt-cache-key
    responses-clamp-prompt-cache-key
  ) ;export
) ;define-library
