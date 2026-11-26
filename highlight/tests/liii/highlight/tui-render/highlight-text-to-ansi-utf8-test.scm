;; highlight-text-to-ansi
;; 验收用例：中文文本渲染为 ANSI 字符串时不发生 UTF-8 断裂——
;; 多字节中文字符的字节序列必须在结果中连续，不被 ANSI 转义前缀/重置码打断。
;;
;; 语法
;; ----
;; (highlight-text-to-ansi text def th)
;;
;; 参数
;; ----
;; text : string
;; 多行文本。
;;
;; def : definition?
;; 语法定义对象。
;;
;; th : theme?
;; 主题对象。
;;
;; 返回值
;; ----
;; string
;; 各行以 \n 连接的 ANSI 渲染结果。

(import (scheme base)
  (liii check)
  (liii string)
  (liii highlight theme)
  (liii highlight definition)
  (liii highlight tui-render)
) ;import

(check-set-mode! 'report-failed)

(let ((th (default-breeze-dark-theme)) (def (load-syntax-definition "scheme")))
  ;; 含中文注释的 Scheme 代码：注释行含中文字符
  (let* ((src (string-append ";; 你好世界，这是中文注释\n"
                "(define (问候 名字)\n" "  ;; 返回问候语\n"
                "  (string-append \"你好, \" 名字))\n"
              ) ;string-append
         ) ;src
         (ans (highlight-text-to-ansi src def th))
        ) ;
    ;; 中文字符串作为完整片段出现在渲染结果中（未被 ANSI 转义从中间打断）
    (check-true (string-contains? ans "你好世界"))
    (check-true (string-contains? ans "你好, "))
    (check-true (string-contains? ans "问候"))
    (check-true (string-contains? ans "返回问候语"))
    ;; 渲染结果包含 ANSI 转义与重置码
    (check-true (string-contains? ans "\x1b;["))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let*

  ;; 纯中文行：每个中文字符的多个 UTF-8 字节合并为连续片段，
  ;; 不应出现 \x1b;[0m 紧跟 \x1b;[ 这种把一个汉字从中间切开的模式
  (let ((ans (highlight-text-to-ansi "你好世界\n" def th)))
    ;; 整个“你好世界”应作为连续子串出现
    (check-true (string-contains? ans "你好世界"))
  ) ;let
) ;let

;; Markdown 中的中文文本
(let ((th (default-breeze-dark-theme)) (md (load-syntax-definition "markdown")))
  (let ((ans (highlight-text-to-ansi "# 中文标题\n\n正文段落，包含 **粗体** 与 `代码`。\n"
               md
               th
             ) ;highlight-text-to-ansi
        ) ;ans
       ) ;
    (check-true (string-contains? ans "中文标题"))
    (check-true (string-contains? ans "正文段落"))
    (check-true (string-contains? ans "粗体"))
    (check-true (string-contains? ans "代码"))
  ) ;let
) ;let

(check-report)
