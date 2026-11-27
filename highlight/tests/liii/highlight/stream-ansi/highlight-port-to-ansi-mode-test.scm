;; highlight-port-to-ansi-mode
;; 模式化流式高亮：char 按语义 token，block 按语义结构片段。
;;
;; 语法
;; ----
;; (highlight-port-to-ansi-mode in out def th mode emit-block)
;; (highlight-port-to-ansi-mode in out def th mode emit-block chunk-size)
;;
;; 参数
;; ----
;; in : input-port?
;; out : output-port?
;; def : definition?
;; th : theme?
;; mode : symbol，char 或 block
;; emit-block : procedure，接收一段 ANSI 文本。
;; chunk-size : integer (可选，默认 8192)
;;
;; 返回值
;; -----
;; unspecified；block 为默认模式（按结构片段交付），
;; char 按 token 交付；两种模式的 ANSI 拼接与整文件渲染一致。

(import (scheme base)
  (liii check)
  (liii path)
  (liii string)
  (liii highlight definition)
  (liii highlight theme)
  (liii highlight tui-render)
  (liii highlight stream-ansi)
) ;import

(check-set-mode! 'report-failed)

(define th (default-breeze-dark-theme))

(define (strip-ansi text)
  (let ((len (string-length text)) (esc (integer->char 27)))
    (let loop
      ((i 0) (acc '()))
      (cond ((= i len) (apply string-append (reverse acc)))
            ((char=? (string-ref text i) esc)
             (let escape
               ((j (+ i 1)))
               (if (or (= j len) (char=? (string-ref text j) #\m))
                 (loop (+ j 1) acc)
                 (escape (+ j 1))
               ) ;if
             ) ;let
            ) ;
            (else
              (loop (+ i 1) (cons (string (string-ref text i)) acc))
            ) ;else
      ) ;cond
    ) ;let
  ) ;let
) ;define

(define (render-mode text def mode chunk-size)
  (let ((out (open-output-string)) (pieces '()))
    (highlight-port-to-ansi-mode (open-input-string text)
      out
      def
      th
      mode
      (lambda (t) (set! pieces (cons t pieces)))
      chunk-size
    ) ;highlight-port-to-ansi-mode
    (list (reverse pieces) (highlight-text-to-ansi text def th))
  ) ;let
) ;define

;; Markdown 使用 JSON 声明的 block 树；fenced code 按子语言展开叶子。
(let* ((def (load-syntax-definition "markdown"))
       (doc (string-append "# 标题\n\n第一段第一行\n第一段第二行\n\n- 项目一\n- 项目二\n\n"
              "```scheme\n(define x 1)\n(define y 2)\n```\n\n结尾无换行"
            ) ;string-append
       ) ;doc
       (r (render-mode doc def 'block 8192))
       (pieces (car r))
       (expected (cadr r))
      ) ;
  ;; 标题、段落、两个列表项、开始 fence、两个 Scheme form、结束 fence、分隔行、尾段。
  (check (length pieces) => 10)
  ;; 小输入块不能改变语义 block 的边界与内容。
  (let ((small-chunks (car (render-mode doc def 'block 1))))
    (check small-chunks => pieces)
  ) ;let
) ;let*

;; 有序/无序列表逐项交付；task list 和列表项续行保持归属。
(let* ((def (load-syntax-definition "markdown"))
       (doc (string-append "1. 第一项\n2. 第二项\n3. 第三项\n\n"
              "- [ ] 待办\n  待办续行\n- 普通项\n"
            ) ;string-append
       ) ;doc
       (pieces (car (render-mode doc def 'block 8192)))
       (expected (highlight-text-to-ansi doc def th))
      ) ;
  (check (length pieces) => 5)
  (check (apply string-append pieces) => expected)
  (check (car (render-mode doc def 'block 1)) => pieces)
) ;let*

;; C++ fence 使用 C++ 的结构规则；未知语言 fence 保留为文本叶子。
(let* ((def (load-syntax-definition "markdown"))
       (doc (string-append "```cpp\nint f() { return 1; }\n```\n" "```unknown\nraw\n```\n")
       ) ;doc
       (pieces (car (render-mode doc def 'block 8192)))
      ) ;
  (check (>= (length pieces) 6) => #t)
  (check (strip-ansi (apply string-append pieces)) => doc)
  (check (car (render-mode doc def 'block 1)) => pieces)
) ;let*

;; 其他语言保持原有语义结构交付方式。
(let* ((def (load-syntax-definition "bash"))
       (doc "echo one\necho two\n")
       (r (render-mode doc def 'block 8192))
       (pieces (car r))
      ) ;
  (check (apply string-append pieces) => (cadr r))
  (check (length pieces) => 2)
) ;let*

;; char：按 token 交付，拼接与整文件一致；块大小不影响结果。
(let* ((def (load-syntax-definition "scheme"))
       (doc "(define x 42) ; c\n")
       (expected (highlight-text-to-ansi doc def th))
      ) ;
  (let ((r (render-mode doc def 'char 8192)))
    (check (apply string-append (car r)) => expected)
    (check (> (length (car r)) 1) => #t)
  ) ;let
  (let ((r (render-mode doc def 'char 1)))
    (check (apply string-append (car r)) => expected)
  ) ;let
) ;let*

;; 未知模式报错。
(let ((def (load-syntax-definition "scheme")))
  (check-catch 'output-mode-error
    (highlight-port-to-ansi-mode (open-input-string "x")
      (open-output-string)
      def
      th
      'weird
      (lambda (t) #f)
    ) ;highlight-port-to-ansi-mode
  ) ;check-catch
) ;let

(check-report)
