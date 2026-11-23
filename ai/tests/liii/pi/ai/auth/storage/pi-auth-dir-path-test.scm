;; pi-auth-dir-path
;; 解析 auth.json 所在配置目录：显式传入优先，缺省 ~/.gf/agent。
;;
;; 语法
;; ----
;; (pi-auth-dir-path opt-config-dir) -> path?
;;
;; 参数
;; ----
;; opt-config-dir : list?
;; '() 或 (dir)，dir 为 string/path。
;;
;; 返回值
;; ----
;; path?
;; 配置目录 path 对象。

(import (liii check) (liii path) (liii pi ai auth storage))

(check-set-mode! 'report-failed)

(define expected-explicit-path
  (path->string (path "/tmp/gf-cfg"))
) ;define

(check (path->string (pi-auth-dir-path '("/tmp/gf-cfg"))) => expected-explicit-path)
(check
  (path->string (pi-auth-dir-path (list (path "/tmp/gf-cfg"))))
  =>
  expected-explicit-path
) ;check
(check (path->string (pi-auth-dir-path '(#f)))
  =>
  (path->string (path-join (path-home) ".gf" "agent"))
) ;check
(check (path->string (pi-auth-dir-path '()))
  =>
  (path->string (path-join (path-home) ".gf" "agent"))
) ;check

(check-report)
