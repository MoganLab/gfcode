;; theme-text-style
;; 查询指定 TextStyle 名的样式属性。
;;
;; 语法
;; ----
;; (theme-text-style th style-name)
;;
;; 参数
;; ----
;; th : theme?
;; 主题对象。
;;
;; style-name : string
;; 样式名，如 "Keyword"。
;;
;; 返回值
;; ----
;; <style-entry> 或 #f
;; 找到返回样式属性，否则 #f。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(let ((th (default-breeze-dark-theme)))
  (check-true (not (not (theme-text-style th "Keyword"))))
  (check-true (not (not (theme-text-style th "Normal"))))
  (check (theme-text-style th "NoSuchStyle") => #f)
) ;let

(check (theme-text-style (make-theme) "Keyword") => #f)

(check-report)
