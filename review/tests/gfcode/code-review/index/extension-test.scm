;; extension
;; code-review 扩展工厂：注册 review 相关 flags、commands、validator、flow 与
;; prompt injector。本文件验证加载与注册结果。
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
;; 加载标记 "code-review-loaded"。

(set! *load-path* (append (list "." "..") *load-path*))

(import (scheme base) (liii check) (liii path) (liii pi code core extensions))

(check-set-mode! 'report-failed)

(define (get-code-review-path)
  (path->string
    (path-resolve (if (path-exists? (path "gfcode/code-review/index.scm"))
                    (path "gfcode/code-review/index.scm")
                    (path "../gfcode/code-review/index.scm")
                  ) ;if
    ) ;path-resolve
  ) ;path->string
) ;define

;; 1. 加载扩展并验证注册项
(let* ((api (make-extension-api))
       (res (pi-load-extension (get-code-review-path) api))
      ) ;
  (check (eq? (cdr (assq 'status res)) 'ok) => #t)
  (check (equal? (cdr (assq 'value res)) "code-review-loaded") => #t)
  (check (extension-flag-def? (find-extension-flag api "--code-review")) => #t)
  (check (find-extension-flag api "--auto-review") => #f)
  (check (extension-flag-def? (find-extension-flag api "--staged")) => #t)
  (check (extension-flag-def? (find-extension-flag api "--ref")) => #t)
  (check (extension-command-def? (find-extension-command api "/review")) => #t)
  (check (extension-command-def? (find-extension-command api "review")) => #t)
  (check (extension-flow-def? (find-extension-flow api 'code-review)) => #t)
  (check (pair? (extension-registry-prompt-injectors-list api)) => #t)
  (check (pair? (extension-registry-validators-list api)) => #t)
) ;let*

(check-report)
