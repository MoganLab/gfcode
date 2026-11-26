;; highlight-line (IncludeRules)
;; 验证 IncludeRules 跨语言嵌入：HTML 的 <style> 块内嵌 CSS 高亮。
;;
;; 语法
;; ----
;; (highlight-line text state def)
;;
;; 参数
;; ----
;; text : string
;; 当前行文本（不含换行符）。
;;
;; state : highlight-state?
;; 进入本行前的高亮状态。
;;
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; values
;; 两个值：spans 列表 '((offset length item-data) ...) 与下一行的高亮状态。

(import (scheme base)
  (liii check)
  (liii list)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

(define (span-with-style? spans style)
  (any (lambda (sp) (string=? (caddr sp) style)) spans)
) ;define

;; HTML def 能加载，且含 CSS 子定义嵌入
(let ((def (load-syntax-definition "html")))
  (check-true (definition? def))

  ;; 单行：<style> 内的 CSS 被识别为 CSS 属性/选择器
  (let-values (((spans st)
                (highlight-line "<style>p { color: red; }</style>"
                  (initial-highlight-state def)
                  def
                ) ;highlight-line
               ) ;
              ) ;
    ;; p 命中 CSS 的 Selector 属性
    (check-true (span-with-style? spans "Selector"))
    ;; color 命中 CSS 的 Property 属性
    (check-true (span-with-style? spans "Property"))
    ;; red 命中 CSS 的 Color 属性
    (check-true (span-with-style? spans "Color"))
    ;; 结束 </style 回到 HTML TagClose 属性
    (check-true (span-with-style? spans "TagClose"))
  ) ;let-values

  ;; 跨行：第一行 <style> 进入嵌入，第二行 CSS 仍被高亮（状态跨行保持）
  (let*-values (((s1 st1) (highlight-line "<style>" (initial-highlight-state def) def))
                ((s2 st2) (highlight-line "body { font-size: 14pt; }" st1 def))
               ) ;
    (check-true (span-with-style? s2 "Selector"))
    (check-true (span-with-style? s2 "Property"))
    (check-true (span-with-style? s2 "Unit"))
  ) ;let*-values

  ;; 嵌入结束：第三行 </style> 退出嵌入，回到 HTML 上下文
  (let*-values (((s1 st1)
                 (highlight-line "<style>p { color: red; }" (initial-highlight-state def) def)
                ) ;
                ((s2 st2) (highlight-line "</style><p>hi</p>" st1 def))
               ) ;
    (check-true (span-with-style? s2 "TagClose"))
    (check-true (span-with-style? s2 "Tag"))
  ) ;let*-values
) ;let

;; CSS def 单独可用（供 IncludeRules 解析）
(let ((def (load-syntax-definition "css")))
  (check-true (definition? def))
  (let-values (((spans st)
                (highlight-line "a { color: red; }" (initial-highlight-state def) def)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Selector"))
    (check-true (span-with-style? spans "Property"))
  ) ;let-values
) ;let

(check-report)
