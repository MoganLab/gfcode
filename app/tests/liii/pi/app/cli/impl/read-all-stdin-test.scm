;; read-all-stdin
;; 读取并拼接标准输入全部内容，去除首尾空白。
;;
;; 语法
;; ----
;; (read-all-stdin) -> string? | #f
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ------
;; string? | #f
;; 标准输入去除首尾空白后的字符串；若输入为空或仅空白则返回 #f。

(import (liii check) (liii string) (liii pi app cli impl))

(check-set-mode! 'report-failed)

;; 1. 非空输入：返回去除首尾空白后的内容
(let ((result (with-input-from-string "  hello stdin  " read-all-stdin)))
  (check result => "hello stdin")
) ;let

;; 2. 仅空白输入：返回 #f
(let ((result (with-input-from-string "   \n\t  " read-all-stdin)))
  (check result => #f)
) ;let

;; 3. 空输入：返回 #f
(let ((result (with-input-from-string "" read-all-stdin)))
  (check result => #f)
) ;let

;; 4. 多行输入：保留内部换行，仅去除首尾空白
(let ((result (with-input-from-string "  line1\nline2\n  " read-all-stdin)))
  (check result => "line1\nline2")
) ;let

(check-report)
