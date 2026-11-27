;; pi-resolve-web-search-provider
;; 解析联网搜索使用的后端 provider。
;;
;; 语法
;; ----
;; (pi-resolve-web-search-provider config opt-provider ws-config . opt-env)
;;
;; 参数
;; ----
;; config : list?
;; 会话配置 alist。
;;
;; opt-provider : (or string? boolean?)
;; 显式传入的 provider 名称。
;;
;; ws-config : (or list? boolean?)
;; web-search.json 解析后的配置 alist。
;;
;; opt-env : (or list? boolean?)（可选）
;; 环境变量 alist（测试可控）。
;;
;; 返回值
;; ----
;; string?
;; 生效的 provider 名称：缺省及不支持的值统一回退 deepseek，只有明确
;; 解析为 google 时才使用 Gemini grounding。

(import (liii check) (gfcode web-search config))

(check-set-mode! 'report-failed)

;; 签名：(pi-resolve-web-search-provider config opt-provider ws-config . opt-env)
;; 优先级：显式 opt > ws-config（web-search.json） > 环境变量 > config

;; 显式 opt 优先
(check (pi-resolve-web-search-provider '() "deepseek" #f) => "deepseek")
(check (pi-resolve-web-search-provider '((provider . "deepseek")) "google" #f)
  =>
  "google"
) ;check
;; 显式 google 始终是受支持分支
(check (pi-resolve-web-search-provider '() "google" #f) => "google")
;; ws-config（web-search.json，全局覆盖：任何会话 provider 都生效）
(check (pi-resolve-web-search-provider '()
         #f
         (make-pi-web-search-config "deepseek" #f #f #f)
       ) ;pi-resolve-web-search-provider
  =>
  "deepseek"
) ;check
(check (pi-resolve-web-search-provider '((provider . "google"))
         #f
         (make-pi-web-search-config "deepseek" #f #f #f)
       ) ;pi-resolve-web-search-provider
  =>
  "deepseek"
) ;check
(check (pi-resolve-web-search-provider '()
         "google"
         (make-pi-web-search-config "deepseek" #f #f #f)
       ) ;pi-resolve-web-search-provider
  =>
  "google"
) ;check
;; ws-config 里不认识的 provider 回退 deepseek
(check (pi-resolve-web-search-provider '()
         #f
         (make-pi-web-search-config "openai" #f #f #f)
       ) ;pi-resolve-web-search-provider
  =>
  "deepseek"
) ;check
;; config 的 web-search-provider 字段
(check (pi-resolve-web-search-provider '((web-search-provider . "deepseek")) #f #f)
  =>
  "deepseek"
) ;check
;; config 的 web-search-provider 为 google 仍走 google
(check (pi-resolve-web-search-provider '((web-search-provider . "google")) #f #f)
  =>
  "google"
) ;check
;; config 的 provider 字段
(check (pi-resolve-web-search-provider '((provider . "deepseek")) #f #f)
  =>
  "deepseek"
) ;check
(check (pi-resolve-web-search-provider '((provider . "google")) #f #f)
  =>
  "google"
) ;check
;; 环境变量
(check (pi-resolve-web-search-provider '()
         #f
         #f
         '(("GF_PI_WEB_SEARCH_PROVIDER" . "deepseek"))
       ) ;pi-resolve-web-search-provider
  =>
  "deepseek"
) ;check
(check (pi-resolve-web-search-provider '()
         #f
         #f
         '(("GF_PI_WEB_SEARCH_PROVIDER" . "google"))
       ) ;pi-resolve-web-search-provider
  =>
  "google"
) ;check
;; 默认 deepseek：空配置
(check (pi-resolve-web-search-provider '() #f #f) => "deepseek")
;; 不认识的 provider 回退 deepseek
(check (pi-resolve-web-search-provider '((provider . "anthropic")) #f #f)
  =>
  "deepseek"
) ;check
(check (pi-resolve-web-search-provider '((provider . "kimi-coding")) #f #f)
  =>
  "deepseek"
) ;check

(check-report)
