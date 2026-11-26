;; theme-editor-color
;; 查询指定编辑器颜色名的 RGB 值。
;;
;; 语法
;; ----
;; (theme-editor-color th color-name)
;;
;; 参数
;; ----
;; th : theme?
;; 主题对象。
;;
;; color-name : string
;; 颜色名，如 "BackgroundColor"。
;;
;; 返回值
;; ----
;; list 或 #f
;; '(r g b) 或 #f。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(check (theme-editor-color (default-breeze-dark-theme) "BackgroundColor")
  =>
  '(35 38 41)
) ;check
(check (theme-editor-color (default-breeze-dark-theme) "NoSuchColor") => #f)
(check (theme-editor-color (make-theme) "BackgroundColor") => #f)

(check-report)
