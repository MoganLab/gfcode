;; 缓存优化：系统提示必须置于 input[0]（纳入可缓存前缀），而非顶层 instructions。
;; OpenAI GPT-5/6 的 prompt cache 仅按序列化 input + tools 计算前缀；
;; 顶层 instructions 不计入缓存（GPT-6.2+ 还会排在 input 之后，命中边界外），
;; 把它放 instructions 会导致缓存命中率趋近 0（OmniRoute PR #1346 的 0% 命中复现）。

(import (liii check)
  (liii json)
  (liii pi ai api openai-responses)
  (liii pi ai message)
  (liii pi ai tools definition)
) ;import

(check-set-mode! 'report-failed)

;; 1) 系统提示在 input[0]，且请求体不带 instructions 字段
(let* ((msgs (list (pi-user-message "hello")))
       (input (responses-build-messages msgs "SYSTEM PROMPT"))
       (body (responses-build-request-body "m" input #t '() 1024 "cache-key"))
      ) ;
  (check-true (not (assoc "instructions" body)))
  (let ((item0 (vector-ref (cdr (assoc "input" body)) 0)))
    (check (cdr (assoc "role" item0)) => "system")
  ) ;let
  ;; prompt_cache_key 进入请求体
  (check (cdr (assoc "prompt_cache_key" body)) => "cache-key")
) ;let*

;; 2) 前缀稳定性：连续两轮对话（仅追加新 user 消息），前 N 项完全一致
(let* ((sys "You are a stable assistant.")
       (turn1 (list (pi-user-message "first question")))
       (input1 (responses-build-messages turn1 sys))
       (asst1 (pi-assistant-message (list (pi-text-block "first answer"))))
       (turn2 (list (pi-user-message "first question")
                asst1
                (pi-user-message "second question")
              ) ;list
       ) ;turn2
       (input2 (responses-build-messages turn2 sys))
      ) ;
  ;; input2 应包含 input1 的全部项作为前缀
  (check (>= (vector-length input2) (vector-length input1)) => #t)
  (let loop
    ((i 0))
    (when (< i (vector-length input1))
      (check (equal? (vector-ref input1 i) (vector-ref input2 i)) => #t)
      (loop (+ i 1))
    ) ;when
  ) ;let
) ;let*

;; 3) 系统提示变化时才会破坏前缀（预期行为，可控）
(let* ((msgs (list (pi-user-message "q")))
       (in-a (responses-build-messages msgs "SYS A"))
       (in-b (responses-build-messages msgs "SYS B"))
      ) ;
  (check (equal? (vector-ref in-a 0) (vector-ref in-b 0)) => #f)
) ;let*

;; 4) 工具声明顺序稳定：同一输入产生相同声明（缓存要求工具定义及顺序稳定）
(let* ((defs
         (list (pi-tool-definition "a" "da" '(("type" . "object")))
           (pi-tool-definition "b" "db" '(("type" . "object")))
         ) ;list
       ) ;defs
       (d1 (responses-build-tool-declarations defs))
       (d2 (responses-build-tool-declarations defs))
      ) ;
  (check (equal? d1 d2) => #t)
  ;; 声明顺序与输入一致
  (check (cdr (assoc "name" (car d1))) => "a")
  (check (cdr (assoc "name" (cadr d1))) => "b")
) ;let*

;; 5) prompt_cache_key 解析：仅官方端点注入（第三方兼容端点保守不注入）
(check (responses-resolve-prompt-cache-key "https://api.openai.com/v1" "sess")
  =>
  "sess"
) ;check
(check (responses-resolve-prompt-cache-key "https://proxy.example.com/v1" "sess")
  =>
  #f
) ;check
(check (responses-resolve-prompt-cache-key "https://api.openai.com/v1" #f)
  =>
  #f
) ;check
(check (responses-resolve-prompt-cache-key "https://api.openai.com/v1" "")
  =>
  #f
) ;check

;; 6) prompt_cache_key 超长截断到 64
(let ((long-key (make-string 100 #\a)))
  (check (string-length (responses-resolve-prompt-cache-key "https://api.openai.com/v1" long-key)
         ) ;string-length
    =>
    64
  ) ;check
) ;let

;; 7) store=false：无状态请求，每次带全量 input（不做服务端会话依赖）
(let* ((input (responses-build-messages (list (pi-user-message "q")) #f))
       (body (responses-build-request-body "m" input #f '() 512))
      ) ;
  (check (cdr (assoc "store" body)) => #f)
) ;let*

(check-report)
