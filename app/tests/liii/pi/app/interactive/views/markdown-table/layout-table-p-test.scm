;; layout-table?
;; 判断布局行是否属于表格。
;;
;; 语法
;; ----
;; (layout-table? line)
;; 参数
;; ----
;; line：markdown-layout-lines 返回的布局行。
;; 返回值
;; ----
;; 表格行返回 #t，普通正文和代码围栏行返回 #f。
(import (scheme base)
  (liii check)
  (liii pi app interactive views markdown-table)
) ;import
(check-set-mode! 'report-failed)
(check (map layout-table?
         (markdown-layout-lines '("```md" "|a|" "|---|" "```" "" "|b|" "|---|"
                                  "|c|"))
       ) ;map
  =>
  '(#f #f #f #f #f #t #t #t)
) ;check

(check-report)
