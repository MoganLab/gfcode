;; pi-resolve-search-model-id
;; 解析联网搜索使用的模型标识，按有效搜索 provider 区分缺省与跨 provider 隔离。
;;
;; 语法
;; ----
;; (pi-resolve-search-model-id config opt-model . opt-provider)
;;
;; 参数
;; ----
;; config : list?
;; 会话配置 alist，可包含 provider 与 model-id 字段。
;;
;; opt-model : (or string? boolean?)
;; 显式传入的模型标识（:model-id 或 web-search.json model）。
;;
;; opt-provider : (or string? boolean?)（可选）
;; 有效搜索后端名称（deepseek/google），用于选择缺省模型与跨 provider 隔离。
;;
;; 返回值
;; ----
;; string?
;; 生效的模型标识字符串。显式模型 > web-search.json 模型 > 匹配会话 provider
;; 的 model-id > provider 专属缺省（deepseek-flash / gemini-2.5-flash）。

(import (liii check) (gfcode web-search config))

(check-set-mode! 'report-failed)

;; 1. 显式传入的模型标识优先（任意 provider）
(check (pi-resolve-search-model-id '() "gemini-3.8-flash" "google")
  =>
  "gemini-3.8-flash"
) ;check
(check (pi-resolve-search-model-id '((model-id . "cfg-model")) "opt-model" "deepseek")
  =>
  "opt-model"
) ;check
(check (pi-resolve-search-model-id '() "deepseek-chat" "deepseek")
  =>
  "deepseek-chat"
) ;check

;; 2. DeepSeek 缺省模型为 deepseek-flash
(check (pi-resolve-search-model-id '() #f "deepseek") => "deepseek-flash")
(check (pi-resolve-search-model-id '() #f "deepseek") => "deepseek-flash")

;; 3. Google 缺省模型仍为 gemini-2.5-flash
(check (pi-resolve-search-model-id '() #f "google") => "gemini-2.5-flash")

;; 4. 会话 provider 与搜索 provider 一致时沿用会话 model-id
(check (pi-resolve-search-model-id '((provider . "deepseek")
                                     (model-id . "ds-custom"))
         #f
         "deepseek"
       ) ;pi-resolve-search-model-id
  =>
  "ds-custom"
) ;check
(check (pi-resolve-search-model-id '((provider . "google")
                                     (model-id . "gemini-pro"))
         #f
         "google"
       ) ;pi-resolve-search-model-id
  =>
  "gemini-pro"
) ;check

;; 5. 跨 provider 不继承会话模型：会话 google/gemini-3.8-flash，搜索 deepseek
;;    使用 DeepSeek 缺省 deepseek-flash，不串用 Gemini 模型 id
(check (pi-resolve-search-model-id '((provider . "google")
                                     (model-id . "gemini-3.8-flash"))
         #f
         "deepseek"
       ) ;pi-resolve-search-model-id
  =>
  "deepseek-flash"
) ;check
;; 反向：会话 deepseek/deepseek-v4-pro，搜索 google 使用 gemini-2.5-flash
(check (pi-resolve-search-model-id '((provider . "deepseek")
                                     (model-id . "deepseek-v4-pro"))
         #f
         "google"
       ) ;pi-resolve-search-model-id
  =>
  "gemini-2.5-flash"
) ;check

;; 6. 显式模型优先级高于会话 model-id（即便跨 provider）
(check (pi-resolve-search-model-id '((provider . "google")
                                     (model-id . "gemini-3.8-flash"))
         "my-explicit-model"
         "deepseek"
       ) ;pi-resolve-search-model-id
  =>
  "my-explicit-model"
) ;check

;; 7. 向后兼容：两参数调用（不带 provider）默认为 Google 缺省 gemini-2.5-flash
(check (pi-resolve-search-model-id '() "gemini-3.8-flash")
  =>
  "gemini-3.8-flash"
) ;check
(check (pi-resolve-search-model-id '((model-id . "cfg-model")) #f)
  =>
  "cfg-model"
) ;check
(check (pi-resolve-search-model-id '() #f) => "gemini-2.5-flash")

;; 8. 显式空白模型视为未指定，回退缺省
(check (pi-resolve-search-model-id '() "   " "deepseek") => "deepseek-flash")
(check (pi-resolve-search-model-id '() "" "google") => "gemini-2.5-flash")

(check-report)
