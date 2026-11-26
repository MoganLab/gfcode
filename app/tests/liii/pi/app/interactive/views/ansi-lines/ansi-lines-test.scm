;; (%diff-visual-lines rows expanded? width) lays out validated logical rows.
;; 语法: (%diff-visual-lines rows expanded? width)
;; 参数: 合法逻辑行、展开状态及正文列数。
;; 返回值: 带受控前景的视觉行；外部数据先经 %diff-rows? 校验。
;; (%diff-rows? value) rejects unsafe text, unknown styles and split UTF-8.
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
  '("\x1b;[38;2;190;242;200m+中\x1b;[39m")
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
  '("\x1b;[38;2;255;190;190mr\x1b;[39m" "\x1b;[38;2;140;210;220mh\x1b;[39m"
    "\x1b;[38;2;167;152;215mf\x1b;[39m" "\x1b;[38;2;157;165;169mn\x1b;[39m")
) ;check

(check-report)
