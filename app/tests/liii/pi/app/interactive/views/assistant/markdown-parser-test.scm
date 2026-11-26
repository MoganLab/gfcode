;; %make-markdown-parser : loader -> (raw Markdown -> rows or #f).
;; Sanitized, width-independent rows; unavailable definitions are cached failures.
;; 语法
;; ----
;; (%make-markdown-parser loader)
;; 参数
;; ----
;; loader：当前 worker 的定义加载过程。
;; 返回值
;; ----
;; 解析过程：输入原始字符串，返回安全行或 #f。
(import (scheme base)
  (liii check)
  (liii string)
  (liii tui text-width)
  (liii highlight definition)
  (liii pi app interactive views markdown)
  (liii pi app interactive views ansi-lines)
  (liii pi code utils shell)
) ;import
(check-set-mode! 'report-failed)

(define parse
  (%make-markdown-parser (lambda () (load-syntax-definition "markdown")))
) ;define

(define raw
  "# 中文\x1b;[31m标题\x1b;[0m\n\x1b;]0;bad\x07;**粗体**\x1b;c\n```diff\n+ok\n```\n"
) ;define

(check (car (%markdown-visual-lines (parse "`(liii tui)`") 80))
  =>
  "\x1b;[38;2;167;152;215m`(liii tui)`\x1b;[0m"
) ;check

(check (car (%markdown-visual-lines (parse "# 标题") 80))
  =>
  "\x1b;[38;2;205;154;34m\x1b;[1m\x1b;[4m# 标题\x1b;[0m"
) ;check

(define heading3
  "### 核心原因：今天执行的其实还是修改前的旧 Cron 批次（外加 GitHub 队列积压）"
) ;define
(check (%markdown-visual-lines (parse heading3) 120)
  =>
  (list (string-append "\x1b;[38;2;205;154;34m\x1b;[1m" heading3 "\x1b;[0m"))
) ;check

(define rows (parse raw))
(check (map car rows) => (string-split (sanitize-display-text raw) "\n"))
(check-true (%markdown-rows? rows))
(check (map strip-ansi (%markdown-visual-lines rows 80))
  =>
  (wrap-text (sanitize-display-text raw) 80)
) ;check
(check-true (string-contains? (string-join (%markdown-visual-lines rows 80) "") "\x1b;[")
) ;check-true
(check-false
  (%markdown-rows? '(("\x1b;c" (0 2 "Normal"))))
) ;check-false

;; Verify semantic roles, not just the presence of an ANSI escape.

(define (roles text)
  (map (lambda (row) (map caddr (cdr row))) (parse text))
) ;define
(check (roles "[link](https://x)\n> quote\n```unknown\ntext\n```")
  =>
  '(("Link" "Muted") ("Quote") ("Muted") ("CodeBlock") ("Muted"))
) ;check
(check (roles "```python\nreturn 42\n```")
  =>
  '(("Muted") ("Keyword" "Plain" "Number") ("Muted"))
) ;check

(define controls
  (string-append "a\t\r\nb" (byte-vector->string (byte-vector 255)))
) ;define
(check (string-join (map car (parse controls)) "\n")
  =>
  (sanitize-display-text controls)
) ;check
(check-false (parse (make-string 2049 #\a)))
(check-false (parse (apply string-append (make-list 129 "中\n"))))
(check-false (parse (make-string 17000 #\a)))

(define calls 0)

(define broken
  (%make-markdown-parser (lambda () (set! calls (+ calls 1)) (error "missing")))
) ;define
(check-false (broken "a"))
(check-false (broken "b"))
(check calls => 1)

(check-report)
