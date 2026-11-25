;; extension
;; web-search 扩展工厂：注册 web_search 工具并声明默认启用。
;; 本文件验证加载与注册结果。
;;
;; 语法
;; ----
;; (extension api . opt-context)
;;
;; 参数
;; ----
;; api : extension-api?
;; 扩展宿主 API 实例。
;;
;; opt-context : extension-context（可选）
;; 扩展上下文。
;;
;; 返回值
;; ----
;; string?
;; 加载标记 "web-search-loaded"。

(set! *load-path*
  (append (list "../review" "../simplify" "../web-search" "review" "simplify"
            "web-search"
          ) ;list
    *load-path*
  ) ;append
) ;set!

(import (scheme base) (liii check) (liii path) (liii pi code core extensions))

(check-set-mode! 'report-failed)

(define (get-web-search-path)
  (let ((test-path (path-resolve "tests/gfcode/web-search/extension-test.scm")))
    (path->string
      (path-resolve
        (path-join
          (path-parent (path-parent (path-parent (path-parent test-path))))
          "gfcode"
          "web-search.scm"
        ) ;path-join
      ) ;path-resolve
    ) ;path->string
  ) ;let
) ;define

;; 1. 加载扩展并验证 web_search 工具注册
(let* ((api (make-extension-api))
       (res (pi-load-extension (get-web-search-path) api))
       (tool (find-extension-tool api "web_search"))
      ) ;
  (check (eq? (cdr (assq 'status res)) 'ok) => #t)
  (check (equal? (cdr (assq 'value res)) "web-search-loaded") => #t)
  (check (extension-tool-def? tool) => #t)
  (check (procedure? (extension-tool-def-execute tool)) => #t)
  (check (extension-tool-def-default-active? tool) => #t)
  (check (extension-registry-default-tool-names api) => '("web_search"))
) ;let*

(check-report)
