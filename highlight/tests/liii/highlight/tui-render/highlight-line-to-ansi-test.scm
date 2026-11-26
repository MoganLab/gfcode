;; highlight-line-to-ansi
;; 单行高亮并渲染为 ANSI 字符串。
;;
;; 语法
;; ----
;; (highlight-line-to-ansi line state def th)
;;
;; 参数
;; ----
;; line : string
;; 当前行文本。
;;
;; state : highlight-state?
;; 进入本行前的高亮状态。
;;
;; def : definition?
;; 语法定义对象。
;;
;; th : theme?
;; 主题对象。
;;
;; 返回值
;; ----
;; values
;; 两个值：渲染后的 ANSI 字符串与下一行的高亮状态。

(import (scheme base)
  (liii check)
  (liii string)
  (liii highlight theme)
  (liii highlight definition)
  (liii highlight highlighter)
  (liii highlight tui-render)
) ;import

(check-set-mode! 'report-failed)

(let ((th (default-breeze-dark-theme)) (def (load-syntax-definition "scheme")))
  ;; define 行：带转义序列且含重置码
  (let-values (((rendered s)
                (highlight-line-to-ansi "(define x 42)" (initial-highlight-state def) def th)
               ) ;
              ) ;
    (check-true (string-contains? rendered "\x1b;["))
    (check-true (string-contains? rendered "\x1b;[0m"))
    (check (car (highlight-state-stack s)) => "Level0")
  ) ;let-values

  ;; 注释行进入并自动 pop
  (let-values (((rendered s)
                (highlight-line-to-ansi ";; note" (initial-highlight-state def) def th)
               ) ;
              ) ;
    (check-true (string-contains? rendered "note"))
    (check (car (highlight-state-stack s)) => "Level0")
  ) ;let-values

  ;; 字符串跨行：状态进入 string
  (let-values (((rendered s)
                (highlight-line-to-ansi "\"abc" (initial-highlight-state def) def th)
               ) ;
              ) ;
    (check (car (highlight-state-stack s)) => "string")
    ;; 第二行用上一状态继续
    (let-values (((r2 s2) (highlight-line-to-ansi "def\"" s def th)))
      (check (car (highlight-state-stack s2)) => "Level0")
    ) ;let-values
  ) ;let-values
) ;let

(check-report)
