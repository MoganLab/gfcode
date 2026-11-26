;; %diff-visual-lines
;; 将已校验的逻辑行折叠、着色并按显示宽度折行。
;;
;; 语法
;; ----
;; (%diff-visual-lines rows expanded? width)
;;
;; 参数
;; ----
;; rows 为通过 %diff-rows? 校验的逻辑行，expanded? 为展开状态，width 为正文列数。
;;
;; 返回值
;; ----
;; 带受控 ANSI 前景色的视觉行列表。
(import (scheme base)
  (liii check)
  (liii tui text-width)
  (liii pi app interactive views ansi-lines)
) ;import
(check-set-mode! 'report-failed)

(define row '("+中" (0 4 "Added")))
(check (%diff-rows? (list row)) => #t)
(check
  (%diff-rows? '(("+中" (0 2 "Added") (2 2 "Normal"))))
  =>
  #f
) ;check
(check
  (%diff-rows? '(("\x1b;c" (0 2 "Normal"))))
  =>
  #f
) ;check
(check (%diff-visual-lines (list row) #f 4)
  =>
  '("\x1b;[38;2;104;183;141m+中\x1b;[39m")
) ;check
(check (map strip-ansi (%diff-visual-lines (list row) #t 2)) => '("+" "中"))
(check (map strip-ansi (%diff-visual-lines (make-list 11 row) #f 80))
  =>
  (append (make-list 10 "+中") '("... (1 more lines, ctrl+o to expand)"))
) ;check
(check
  (%diff-visual-lines '(("r" (0 1 "Removed"))
                        ("h" (0 1 "Header"))
                        ("f" (0 1 "File"))
                        ("n" (0 1 "Normal")))
    #t
    4
  ) ;%diff-visual-lines
  =>
  '("\x1b;[38;2;234;127;129mr\x1b;[39m" "\x1b;[38;2;157;165;169mh\x1b;[39m"
    "\x1b;[38;2;157;165;169mf\x1b;[39m" "\x1b;[38;2;157;165;169mn\x1b;[39m")
) ;check

(check-report)
