;; pi-normalize-web-search-urls
;; 规范化 web_search 工具的 urls 参数：vector 转 list，list 原样返回。
;;
;; 语法
;; ----
;; (pi-normalize-web-search-urls urls)
;;
;; 参数
;; ----
;; urls : any?
;; 原始 urls 参数值。string->json 把 JSON 数组解析为 vector，
;; 手写 alist 参数常用 list，两种表示都规范化为 list。
;;
;; 返回值
;; ----
;; any?
;; vector 输入返回对应 list；list 输入原样返回；
;; 其他类型（含 #f）原样返回，交由校验函数报错。

(import (liii check) (gfcode web-search schema))

(check-set-mode! 'report-failed)

;; vector（JSON 解析产物）转 list
(check (pi-normalize-web-search-urls #("https://example.com" "https://example.org"))
  =>
  '("https://example.com" "https://example.org")
) ;check
(check (pi-normalize-web-search-urls #()) => '())

;; list 原样返回
(check (pi-normalize-web-search-urls '("https://example.com"))
  =>
  '("https://example.com")
) ;check
(check (pi-normalize-web-search-urls '()) => '())

;; 其他类型原样返回，由校验函数负责报错
(check (pi-normalize-web-search-urls #f) => #f)
(check (pi-normalize-web-search-urls "https://example.com")
  =>
  "https://example.com"
) ;check
(check (pi-normalize-web-search-urls 42) => 42)

(check-report)
