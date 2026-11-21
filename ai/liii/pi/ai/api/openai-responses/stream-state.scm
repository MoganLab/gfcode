;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; OpenAI Responses API 流式状态记录：累积 blocks / usage / stop-reason /
;; 工具调用 / 思考内容，与 openai-completions stream-state 字段对齐。
(define-library (liii pi ai api openai-responses stream-state)
  (import (scheme base) (liii base))
  (export make-responses-stream-state responses-stream-state?
    responses-stream-state-blocks responses-stream-state-blocks-set!
    responses-stream-state-last-text responses-stream-state-last-text-set!
    responses-stream-state-usage responses-stream-state-usage-set!
    responses-stream-state-stop-reason responses-stream-state-stop-reason-set!
    responses-stream-state-error-message
    responses-stream-state-error-message-set! responses-stream-state-tools
    responses-stream-state-tools-set! responses-stream-state-last-reasoning
    responses-stream-state-last-reasoning-set!
  ) ;export
  (begin

    (define*-record-type <responses-stream-state>
      (make-responses-stream-state (blocks '())
        (last-text #f)
        (usage '())
        (stop-reason "stop")
        (error-message #f)
        (tools '())
        (last-reasoning #f)
      ) ;make-responses-stream-state
      responses-stream-state?
      (blocks responses-stream-state-blocks responses-stream-state-blocks-set!)
      (last-text responses-stream-state-last-text
        responses-stream-state-last-text-set!
      ) ;last-text
      (usage responses-stream-state-usage responses-stream-state-usage-set!)
      (stop-reason responses-stream-state-stop-reason
        responses-stream-state-stop-reason-set!
      ) ;stop-reason
      (error-message responses-stream-state-error-message
        responses-stream-state-error-message-set!
      ) ;error-message
      (tools responses-stream-state-tools responses-stream-state-tools-set!)
      (last-reasoning responses-stream-state-last-reasoning
        responses-stream-state-last-reasoning-set!
      ) ;last-reasoning
    ) ;define*-record-type

  ) ;begin
) ;define-library
