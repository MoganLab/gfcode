;; style->ansi-prefix
;; 生成样式的 ANSI 转义前缀。
;;
;; 语法
;; ----
;; (style->ansi-prefix style-entry)
;;
;; 参数
;; ----
;; style-entry : <style-entry> 或 #f
;; 样式属性对象；#f 表示无样式。
;;
;; 返回值
;; ----
;; string
;; 24 位真彩色 ANSI 转义序列（含 bold/italic/underline）；无属性时返回空串。

(import (scheme base)
  (liii check)
  (liii string)
  (liii highlight theme)
  (liii highlight tui-render)
) ;import

(check-set-mode! 'report-failed)

;; #f 无样式
(check (style->ansi-prefix #f) => "")

;; 全空样式
(check (style->ansi-prefix (make-style-entry)) => "")

;; 仅前景色：38;2;R;G;B
(let ((pfx (style->ansi-prefix (make-style-entry '(255 0 0)))))
  (check-true (string-contains? pfx "38;2;255;0;0"))
  (check-true (string-starts? pfx "\x1b;["))
  (check-true (string-ends? pfx "m"))
) ;let

;; 前景 + 背景色：48;2;...
(let ((pfx (style->ansi-prefix (make-style-entry '(1 2 3) '(4 5 6)))))
  (check-true (string-contains? pfx "38;2;1;2;3"))
  (check-true (string-contains? pfx "48;2;4;5;6"))
) ;let

;; 粗体 / 斜体 / 下划线码
(check-true (string-contains? (style->ansi-prefix (make-style-entry #f #f #t)) "1m")
) ;check-true
(check-true (string-contains? (style->ansi-prefix (make-style-entry #f #f #f #t)) "3m")
) ;check-true
(check-true (string-contains? (style->ansi-prefix (make-style-entry #f #f #f #f #t)) "4m")
) ;check-true

;; Breeze Dark Keyword：有前景色且加粗
(let ((pfx (style->ansi-prefix (theme-text-style (default-breeze-dark-theme) "Keyword"))
      ) ;pfx
     ) ;
  (check-true (string-contains? pfx "38;2;"))
  (check-true (string-contains? pfx ";1m"))
) ;let

(check-report)
