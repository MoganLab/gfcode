;; default-breeze-dark-theme
;; 返回内置 Breeze Dark 主题。
;;
;; 语法
;; ----
;; (default-breeze-dark-theme)
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; <theme>
;; 内置 Breeze Dark 主题对象，无需外部 I/O。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(let ((th (default-breeze-dark-theme)))
  (check (theme? th) => #t)
  (check (theme-name th) => "Breeze Dark")
  ;; 核心样式齐全
  (check-true (not (not (theme-text-style th "Keyword"))))
  (check-true (not (not (theme-text-style th "Normal"))))
  (check-true (not (not (theme-text-style th "Comment"))))
  (check-true (not (not (theme-text-style th "String"))))
  ;; Keyword 加粗
  (check-true (style-entry-bold? (theme-text-style th "Keyword")))
  ;; 编辑器背景色
  (check (theme-editor-color th "BackgroundColor") => '(35 38 41))
) ;let

(check-report)
