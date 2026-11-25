;; extension
;; simplify 扩展工厂：注册 simplify 相关 flags、commands、validator 与 flow。
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
;; 加载标记 "simplify-loaded"。

(set! *load-path*
  (append (list "../review" "../simplify" "../web-search" "review" "simplify"
            "web-search"
          ) ;list
    *load-path*
  ) ;append
) ;set!

(import (scheme base) (liii check) (liii path) (liii pi code core extensions))

(check-set-mode! 'report-failed)

(define (get-simplify-path)
  (let ((test-path (path-resolve "tests/gfcode/simplify/extension-test.scm")))
    (path->string
      (path-resolve
        (path-join
          (path-parent (path-parent (path-parent (path-parent test-path))))
          "gfcode"
          "simplify.scm"
        ) ;path-join
      ) ;path-resolve
    ) ;path->string
  ) ;let
) ;define

;; 1. 加载扩展并验证注册项
(let* ((api (make-extension-api)) (res (pi-load-extension (get-simplify-path) api)))
  (check (eq? (cdr (assq 'status res)) 'ok) => #t)
  (check (equal? (cdr (assq 'value res)) "simplify-loaded") => #t)
  (check (extension-flag-def? (find-extension-flag api "--simplify")) => #t)
  (check (extension-flag-def? (find-extension-flag api "--apply")) => #t)
  (check (extension-command-def? (find-extension-command api "/simplify")) => #t)
  (check (extension-command-def? (find-extension-command api "simplify")) => #t)
  (check (extension-flow-def? (find-extension-flow api 'simplify)) => #t)
  (check (pair? (extension-registry-validators-list api)) => #t)
) ;let*

(check-report)
