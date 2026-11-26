;; markdown-layout-lines
;; 生成用于渲染和复制的 Markdown 布局行。
;;
;; 语法
;; ----
;; (markdown-layout-lines lines)
;; 参数
;; ----
;; lines：已清理的 Markdown 原文行列表。
;; 返回值
;; ----
;; 按可见宽度对齐表格后的布局行列表。空文档返回空列表。
(import (scheme base)
  (liii check)
  (liii pi app interactive views markdown-table)
) ;import
(check-set-mode! 'report-failed)
(check (markdown-layout-lines '()) => '())
(check (map layout-text (markdown-layout-lines '("名称|n" "---|---:" "a|12")))
  =>
  '("| 名称 |    n |" "| ---- | ---: |" "| a    |   12 |")
) ;check

(check-report)
