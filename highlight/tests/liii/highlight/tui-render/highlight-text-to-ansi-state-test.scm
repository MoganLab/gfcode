;; highlight-text-to-ansi-state
;; 携带跨段状态的多行 ANSI 渲染。
;;
;; 语法
;; ----
;; (highlight-text-to-ansi-state text state def th)
;;
;; 参数
;; ----
;; text : string
;; state : highlight-state?
;; def : definition?
;; th : theme?
;;
;; 返回值
;; -----
;; (values rendered next-state)
;; 与 highlight-text-to-ansi 逐行语义一致，状态可跨调用延续，
;; 供流式渲染分段使用（多行字符串/注释跨段不丢失上下文）。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight theme)
  (liii highlight highlighter)
  (liii highlight tui-render)
) ;import

(check-set-mode! 'report-failed)

(let* ((def (load-syntax-definition "scheme"))
       (th (default-breeze-dark-theme))
       (state (initial-highlight-state def))
       (doc "(define x 42) ; comment\n(display \"你好\")\n")
      ) ;
  ;; 初始状态调用与 highlight-text-to-ansi 一致
  (let-values (((rendered next-state) (highlight-text-to-ansi-state doc state def th)))
    (check rendered => (highlight-text-to-ansi doc def th))
  ) ;let-values
  ;; 分段渲染：多行块注释跨段保持上下文（段内不含末尾换行）
  (let-values (((r1 s1) (highlight-text-to-ansi-state "(f #| a" state def th)))
    (let-values (((r2 s2) (highlight-text-to-ansi-state "b |# 1)" s1 def th)))
      (check (string-append r1 "\n" r2)
        =>
        (highlight-text-to-ansi "(f #| a\nb |# 1)" def th)
      ) ;check
    ) ;let-values
  ) ;let-values
) ;let*

(check-report)
