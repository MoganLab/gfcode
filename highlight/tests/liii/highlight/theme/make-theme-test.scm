;; make-theme
;; 构造主题对象。
;;
;; 语法
;; ----
;; (make-theme)
;; (make-theme name styles editor-colors revision)
;;
;; 参数
;; ----
;; name : string (可选)
;; 主题名，默认 "Default"。
;;
;; styles : list (可选)
;; (("StyleName" . <style-entry>) ...)，默认 '()。
;;
;; editor-colors : list (可选)
;; (("ColorName" . '(r g b)) ...)，默认 '()。
;;
;; revision : integer (可选)
;; 版本号，默认 1。
;;
;; 返回值
;; ----
;; <theme>
;; 主题对象。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(let ((th (make-theme)))
  (check (theme-name th) => "Default")
  (check (theme-text-style th "Keyword") => #f)
  (check (theme-editor-color th "BackgroundColor") => #f)
  (check (theme-revision th) => 1)
) ;let

(let ((th (make-theme "My" (list (cons "Keyword" (make-style-entry))) '() 7)))
  (check (theme-name th) => "My")
  (check-true (not (not (theme-text-style th "Keyword"))))
  (check (theme-revision th) => 7)
) ;let

(check-report)
