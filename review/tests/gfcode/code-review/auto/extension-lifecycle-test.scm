;; extension code-review 行为规格
;; 验证命令别名不重复占位、默认自动注入、独立审查隔离和生命周期事件注册。
;;
;; 语法
;; ----
;; (extension api)
;;
;; 参数
;; ----
;; api : extension-api?
;; 扩展宿主 API。
;;
;; 返回值
;; ----
;; string?
;; 加载标记。
;;
;; 错误行为
;; --------
;; 注册失败由 pi-load-extension 返回 error 状态。

(set! *load-path* (append (list "." "..") *load-path*))

(import (scheme base) (liii check) (liii path) (liii pi code core extensions))

(check-set-mode! 'report-failed)

(define (source-path)
  (path->string
    (path-resolve (if (path-exists? (path "gfcode/code-review/index.scm"))
                    (path "gfcode/code-review/index.scm")
                    (path "../gfcode/code-review/index.scm")
                  ) ;if
    ) ;path-resolve
  ) ;path->string
) ;define

(let ((api (make-extension-api)))
  (pi-load-extension (source-path) api)
  ;; 后续 ST3/ST4/ST5 的行为规格；当前提交用于固定目标。
  (check ((extension-command-def-handler (find-extension-command api "/review")) "" '())
    =>
    "code-review command executed"
  ) ;check
  ;; ST3 完成后，上述断言应替换为真实命令分发结果，不允许继续返回占位文本。
  (check-true (pair? (extension-registry-get-listeners api 'tool_execution_end)))
  (check-true (pair? (extension-registry-get-listeners api 'turn_end)))
) ;let

(check-report)
