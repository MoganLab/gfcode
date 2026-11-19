;; pi-provider-entry-headers
;; 读取 provider 条目中声明的 HTTP 请求头（extras 中的 headers 字段）。
;;
;; 语法
;; ----
;; (pi-provider-entry-headers entry) -> alist | #f
;;
;; 参数
;; ----
;; entry : pi-provider-entry? | alist
;;   记录条目从 extras 中取 headers；原始 JSON alist 直接按 "headers" 键取值。
;;
;; 返回值
;; ----
;; alist | #f
;; ((header-name . value) ...)；未声明 headers 时返回 #f。

(import (scheme base) (liii check) (liii pi code config user-providers))

(check-set-mode! 'report-failed)

;; 记录条目：headers 保存在 extras 中。
(check (pi-provider-entry-headers
         (make-pi-provider-entry #f #f #f #f #f #f
           '(("headers" ("x-key" . "v")))
         ) ;make-pi-provider-entry
       ) ;pi-provider-entry-headers
  =>
  '(("x-key" . "v"))
) ;check

;; 未声明 headers 时返回 #f。
(check (pi-provider-entry-headers (make-pi-provider-entry)) => #f)

;; 原始 JSON alist 输入直接读取 headers 键。
(check (pi-provider-entry-headers '(("headers" ("x-key" . "v"))))
  =>
  '(("x-key" . "v"))
) ;check
(check (pi-provider-entry-headers '(("baseUrl" . "https://example.com"))) => #f)

(check-report)
