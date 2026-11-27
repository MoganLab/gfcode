;; highlight-port-to-ansi-streaming
;; 端口级流式高亮：按块读取输入端口，结构事件驱动 ANSI 输出。
;;
;; 语法
;; ----
;; (highlight-port-to-ansi-streaming in out def th)
;; (highlight-port-to-ansi-streaming in out def th chunk-size)
;;
;; 参数
;; ----
;; in : input-port?
;; out : output-port?
;; def : definition?
;; th : theme?
;; chunk-size : integer (可选，默认 8192)
;;
;; 返回值
;; -----
;; unspecified；ANSI 文本写入 out。
;; 流式输出与整文件 highlight-text-to-ansi 结果一致。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight theme)
  (liii highlight tui-render)
  (liii highlight stream-ansi)
) ;import

(check-set-mode! 'report-failed)

(define th (default-breeze-dark-theme))

(define (render-streaming text def chunk-size)
  (let ((out (open-output-string)))
    (highlight-port-to-ansi-streaming (open-input-string text)
      out
      def
      th
      chunk-size
    ) ;highlight-port-to-ansi-streaming
    (get-output-string out)
  ) ;let
) ;define

;; Scheme：多种块大小与整文件渲染一致。
(let ((def (load-syntax-definition "scheme"))
      (doc "(define x 42) ; comment\n(display \"你好\")\n")
     ) ;
  (let ((expected (highlight-text-to-ansi doc def th)))
    (check (render-streaming doc def 8192) => expected)
    (check (render-streaming doc def 1) => expected)
    (check (render-streaming doc def 7) => expected)
  ) ;let
) ;let

;; Markdown：标题 + fenced code，逐字符与整文件一致。
(let ((def (load-syntax-definition "markdown"))
      (doc "# 标题\n```scheme\n(define x 1)\n```\n正文\n")
     ) ;
  (let ((expected (highlight-text-to-ansi doc def th)))
    (check (render-streaming doc def 8192) => expected)
    (check (render-streaming doc def 1) => expected)
  ) ;let
) ;let

;; JSON：嵌套容器。
(let ((def (load-syntax-definition "json")) (doc "{\"a\": [1, {\"b\": true}]}\n"))
  (check (render-streaming doc def 3) => (highlight-text-to-ansi doc def th))
) ;let

;; C++：括号结构与注释。
(let ((def (load-syntax-definition "cpp"))
      (doc "int main() {\n  return 0; // ok\n}\n")
     ) ;
  (check (render-streaming doc def 5) => (highlight-text-to-ansi doc def th))
) ;let

;; 无末尾换行与空输入。
(let ((def (load-syntax-definition "scheme")))
  (check (render-streaming "(+ 1 2)" def 8192)
    =>
    (highlight-text-to-ansi "(+ 1 2)" def th)
  ) ;check
  (check (render-streaming "" def 8192) => "")
) ;let

(check-report)
