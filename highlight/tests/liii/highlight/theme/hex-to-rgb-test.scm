;; hex->rgb
;; 解析十六进制颜色串为 RGB 分量。
;;
;; 语法
;; ----
;; (hex->rgb hex-str)
;;
;; 参数
;; ----
;; hex-str : string
;; 形如 "#rrggbb"、"#aarrggbb" 或不带井号的等价形式。
;;
;; 返回值
;; ----
;; list 或 #f
;; 成功返回 '(r g b)，格式非法返回 #f。

(import (scheme base) (liii check) (liii highlight theme))

(check-set-mode! 'report-failed)

;; 6 位标准形式
(check (hex->rgb "#ffffff") => '(255 255 255))
(check (hex->rgb "#000000") => '(0 0 0))
(check (hex->rgb "#ff0000") => '(255 0 0))
(check (hex->rgb "cfcfc2") => '(207 207 194))

;; 8 位形式忽略 alpha
(check (hex->rgb "#ffcfcfc2") => '(207 207 194))
(check (hex->rgb "#00010203") => '(1 2 3))

;; 非法输入
(check (hex->rgb "bad") => #f)
(check (hex->rgb "#zzzzzz") => #f)
(check (hex->rgb 123) => #f)

(check-report)
