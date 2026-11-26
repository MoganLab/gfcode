;; layout-text
;; 读取布局行中的 Markdown 文本。
;;
;; 语法
;; ----
;; (layout-text line)
;; 参数
;; ----
;; line：markdown-layout-lines 返回的布局行。
;; 返回值
;; ----
;; 纯文本字符串，不含 ANSI 颜色和换行。
(import (scheme base)
  (liii check)
  (liii pi app interactive views markdown-table)
) ;import
(check-set-mode! 'report-failed)
(check (map layout-text (markdown-layout-lines '("  中文 **正文**" "")))
  =>
  '("  中文 **正文**" "")
) ;check

(check-report)
