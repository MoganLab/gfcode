;; pi-resolve-provider-key
;; 解析指定服务商的 API 密钥（优先环境变量，其次 auth 配置，最后 fallback）。
;;
;; 语法
;; ----
;; (pi-resolve-provider-key provider auth-alist)
;; (pi-resolve-provider-key provider auth-alist opt-env)
;;
;; 参数
;; ----
;; provider : string?
;; 服务商名称（如 "deepseek"、"zai-coding-cn" 等）。
;;
;; auth-alist : list?
;; 已加载的凭据列表或 key-value 关联表。
;;
;; opt-env : list?
;; 可选，自定义环境变量列表。
;;
;; 返回值
;; ----
;; string? 或 #f
;; 服务商对应的有效 API 密钥字符串；若未找到则返回 #f。

(import (liii check) (liii pi ai auth))

(check-set-mode! 'report-failed)

;; 1. 优先从环境变量读取
(let ((env '(("DEEPSEEK_API_KEY" . "env-secret-ds"))))
  (check (pi-resolve-provider-key "deepseek" '() env) => "env-secret-ds")
) ;let

;; 2. 环境变量未提供时从 auth-alist 读取
(let ((auth '(("deepseek" . "auth-file-key"))))
  (check (pi-resolve-provider-key "deepseek" auth '()) => "auth-file-key")
) ;let

;; 3. 服务商别名支持（zai-coding-cn ↔ zai）
(let ((auth '(("zai" . "zai-secret"))))
  (check (pi-resolve-provider-key "zai-coding-cn" auth '()) => "zai-secret")
) ;let

;; 3b. opencode 与 opencode-go 环境变量及别名支持
(let ((env '(("OPENCODE_API_KEY" . "env-opencode-key"))))
  (check (pi-resolve-provider-key "opencode" '() env) => "env-opencode-key")
  (check (pi-resolve-provider-key "opencode-go" '() env) => "env-opencode-key")
) ;let
(let ((env '(("OPENCODE_GO_API_KEY" . "env-opencode-go-key"))))
  (check (pi-resolve-provider-key "opencode" '() env) => "env-opencode-go-key")
  (check (pi-resolve-provider-key "opencode-go" '() env) => "env-opencode-go-key")
) ;let
(let ((auth '(("opencode" . "auth-opencode-key"))))
  (check (pi-resolve-provider-key "opencode" auth '()) => "auth-opencode-key")
  (check (pi-resolve-provider-key "opencode-go" auth '()) => "auth-opencode-key")
) ;let

;; 4. 未找到时返回 #f
(check (pi-resolve-provider-key "unknown-provider" '() '()) => #f)

;; 4b. qwen-token-plan-cn 环境变量解析：团队订阅变量优先，回退区域共享变量
(let ((env '(("QWEN_TOKEN_PLAN_TEAM_CN_API_KEY" . "env-team-cn-key"))))
  (check (pi-resolve-provider-key "qwen-token-plan-cn" '() env)
    =>
    "env-team-cn-key"
  ) ;check
) ;let
(let ((env '(("QWEN_TOKEN_PLAN_CN_API_KEY" . "env-cn-shared-key"))))
  (check (pi-resolve-provider-key "qwen-token-plan-cn" '() env)
    =>
    "env-cn-shared-key"
  ) ;check
) ;let
(let ((env '(("QWEN_TOKEN_PLAN_TEAM_CN_API_KEY" . "team")
             ("QWEN_TOKEN_PLAN_CN_API_KEY" . "shared"))))
  (check (pi-resolve-provider-key "qwen-token-plan-cn" '() env) => "team")
) ;let
(let ((auth '(("qwen-token-plan-cn" . "auth-cn-key"))))
  (check (pi-resolve-provider-key "qwen-token-plan-cn" auth '()) => "auth-cn-key")
) ;let
(check (pi-resolve-provider-key "qwen-token-plan-cn" '() '()) => #f)

;; 5. ollama 免密：当无环境变量且无 auth 配置时，回退到默认虚拟密钥 "ollama"
(check (pi-resolve-provider-key "ollama" '() '()) => "ollama")
(let ((env '(("OLLAMA_API_KEY" . "custom-ollama-key"))))
  (check (pi-resolve-provider-key "ollama" '() env) => "custom-ollama-key")
) ;let
(let ((auth '(("ollama" . "auth-ollama-key"))))
  (check (pi-resolve-provider-key "ollama" auth '()) => "auth-ollama-key")
) ;let

(check-report)
