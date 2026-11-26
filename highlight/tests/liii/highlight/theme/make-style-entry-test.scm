;; make-style-entry
;; 构造样式属性对象。
;;
;; 语法
;; ----
;; (make-style-entry)
;; (make-style-entry text-color background-color bold italic underline)
;;
;; 参数
;; ----
;; text-color : list 或 #f (可选)
;; 前景色 '(r g b)，默认 #f。
;;
;; background-color : list 或 #f (可选)
;; 背景色 '(r g b)，默认 #f。
;;
;; bold : boolean (可选)
;; 是否加粗，默认 #f。
;;
;; italic : boolean (可选)
;; 是否斜体，默认 #f。
;;
;; underline : boolean (可选)
;; 是否下划线，默认 #f。
;;
;; 返回值
;; ----
;; <style-entry>
;; 样式属性对象。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

(let ((s (make-style-entry)))
  (check (style-entry-text-color s) => #f)
  (check (style-entry-bg-color s) => #f)
  (check (style-entry-bold? s) => #f)
  (check (style-entry-italic? s) => #f)
  (check (style-entry-underline? s) => #f)
) ;let

(let ((s (make-style-entry '(1 2 3) '(4 5 6) #t #f #t)))
  (check (style-entry-text-color s) => '(1 2 3))
  (check (style-entry-bg-color s) => '(4 5 6))
  (check (style-entry-bold? s) => #t)
  (check (style-entry-italic? s) => #f)
  (check (style-entry-underline? s) => #t)
) ;let

(check-report)
