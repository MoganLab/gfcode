;; %normalize-code-lang : fence info token -> bundled language id or #f.
;; Unknown names (including paths) cannot cause disk lookups or cache growth.
;; 语法
;; ----
;; (%normalize-code-lang name)
;; 参数
;; ----
;; name：围栏语言标识。
;; 返回值
;; ----
;; 内置语言名；未知语言返回 #f。
(import (scheme base) (liii check) (liii highlight code-block))
(check-set-mode! 'report-failed)
(check (map %normalize-code-lang '("ss" "C++" "JS" "SH" "python" "json" "diff"
                                   "C"))
  =>
  '("scheme" "cpp" "javascript" "bash" "python" "json" "diff" "c")
) ;check
(check-false (%normalize-code-lang "../private"))
(check-false (%normalize-code-lang "unknown-123"))

(check-report)
