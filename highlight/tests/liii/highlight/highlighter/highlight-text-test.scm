;; highlight-text
;; 高亮整段多行文本。
;;
;; 语法
;; ----
;; (highlight-text text def)
;;
;; 参数
;; ----
;; text : string
;; 多行文本，可含 \n 或 \r\n 换行。
;;
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; list
;; '((spans . "line-text") ...)，每行一个元素。

(import (scheme base)
  (liii check)
  (liii list)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

(let ((def (load-syntax-definition "scheme")))
  ;; 三行文本（末尾换行产生一个空行元素）
  (let ((res (highlight-text "(define (foo x)\n  (+ x 1))\n" def)))
    (check (= (length res) 3) => #t)
    ;; 每行结构为 (spans . line-text)
    (check (cdr (car res)) => "(define (foo x)")
    (check (cdr (cadr res)) => "  (+ x 1))")
    (check (cdr (caddr res)) => "")
  ) ;let

  ;; 跨行字符串保持状态
  (let ((res (highlight-text "\"abc\ndef\"\n" def)))
    ;; 第二行 def" 应包含 String span
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "String")) (caadr res))
    ) ;check-true
  ) ;let

  ;; CRLF 换行
  (let ((res (highlight-text "a\r\nb\r\n" def)))
    (check (= (length res) 3) => #t)
    (check (cdr (car res)) => "a")
    (check (cdr (cadr res)) => "b")
  ) ;let
) ;let

;; JSON 结构高亮测试
(let* ((jdef (load-syntax-definition "json"))
       (code "{\n  \"name\": \"test\",\n  \"count\": 42,\n  \"ratio\": 3.14,\n  \"items\": [null, true, false]\n}\n"
       ) ;code
       (res (highlight-text code jdef))
      ) ;
  (check (> (length res) 4) => #t)
  ;; 第一行包含对象开括号 Function
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Function")) (caar res))
  ) ;check-true
  ;; 第二行包含键 DataType 与值 String
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "DataType")) (caadr res))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "String")) (caadr res))
  ) ;check-true
) ;let*

;; C++ 结构高亮测试
(let* ((cppdef (load-syntax-definition "cpp"))
       (code "#include <iostream>\n\n// comment\nint main() {\n  return 0;\n}\n")
       (res (highlight-text code cppdef))
      ) ;
  (check (> (length res) 4) => #t)
  ;; 第一行包含 Preprocessor 和 String
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Preprocessor")) (caar res))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "String")) (caar res))
  ) ;check-true
  ;; 第 3 行是 Comment
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Comment")) (car (list-ref res 2)))
  ) ;check-true
) ;let*

;; C 结构高亮测试
(let* ((cdef (load-syntax-definition "c"))
       (code "/* header */\n#include \"test.h\"\n\nint main(void) {\n  return 0;\n}\n")
       (res (highlight-text code cdef))
      ) ;
  (check (> (length res) 4) => #t)
  ;; 第一行是 Comment
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Comment")) (caar res))
  ) ;check-true
  ;; 第二行包含 Preprocessor 和 String
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Preprocessor")) (caadr res))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "String")) (caadr res))
  ) ;check-true
) ;let*

;; Lua 结构高亮测试
(let* ((luadef (load-syntax-definition "lua"))
       (code "-- header\nlocal str = [[multi\nline]]\nfunction test()\n  return true\nend\n"
       ) ;code
       (res (highlight-text code luadef))
      ) ;
  (check (> (length res) 4) => #t)
  ;; 第一行是 Comment
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Comment")) (caar res))
  ) ;check-true
  ;; 第二、三行是 VerbatimString
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "VerbatimString")) (caadr res))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "VerbatimString"))
      (car (list-ref res 2))
    ) ;any
  ) ;check-true
  ;; 第四行包含 Keyword
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Keyword")) (car (list-ref res 3)))
  ) ;check-true
  ;; 第五行包含 ControlFlow 和 Constant
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "ControlFlow")) (car (list-ref res 4)))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Constant")) (car (list-ref res 4)))
  ) ;check-true
) ;let*

;; Markdown 结构高亮测试
(let* ((mddef (load-syntax-definition "markdown"))
       (doc (string-append "# Title H1\n\n" "## Section H2\n\n"
              "> A blockquote with **bold** and `code`.\n\n" "- [ ] Todo 1\n"
              "- Item 2\n\n" "| Header 1 | Header 2 |\n" "| --- | --- |\n\n"
              "Check [link](https://example.com) here.\n"
            ) ;string-append
       ) ;doc
       (res (highlight-text doc mddef))
      ) ;
  (check (> (length res) 8) => #t)
  ;; 第一行包含 Header H1
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Header H1")) (caar res))
  ) ;check-true
  ;; 第三行包含 Header H2
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Header H2")) (car (list-ref res 2)))
  ) ;check-true
  ;; 引用行包含 Blockquote, Strong Text 与 Code
  (let ((bq-spans (car (list-ref res 4))))
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "Blockquote")) bq-spans)
    ) ;check-true
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "Strong Text")) bq-spans)
    ) ;check-true
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "Code")) bq-spans)
    ) ;check-true
  ) ;let
  ;; 任务列表行包含 List
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "List")) (car (list-ref res 6)))
  ) ;check-true
  ;; 表格行包含 Table
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Table")) (car (list-ref res 9)))
  ) ;check-true
) ;let*

;; Markdown 代码块嵌入测试（Scheme, C++, JSON, Lua, 无语言代码块）
(let* ((mddef (load-syntax-definition "markdown"))
       (code-doc (string-append "```scheme\n" "(define (square x)\n"
                   "  (* x x))\n" "```\n\n" "```cpp\n" "#include <iostream>\n"
                   "int main() { return 0; }\n" "```\n\n" "```json\n"
                   "{\"key\": 123}\n" "```\n\n" "```lua\n" "local v = 42\n"
                   "```\n\n" "```\n" "plain text\n" "```\n"
                 ) ;string-append
       ) ;code-doc
       (res (highlight-text code-doc mddef))
      ) ;
  ;; Scheme 代码块：第 1 行为 Fenced Code，第 2 行含 Extension，第 4 行为 Fenced Code
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Fenced Code")) (caar res))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Extension")) (caadr res))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Fenced Code")) (car (list-ref res 3)))
  ) ;check-true

  ;; C++ 代码块：包含 Preprocessor 与 ControlFlow
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Preprocessor")) (car (list-ref res 6)))
  ) ;check-true
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "ControlFlow")) (car (list-ref res 7)))
  ) ;check-true

  ;; JSON 代码块：包含 DataType 与 DecVal
  (let ((json-spans (car (list-ref res 11))))
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "DataType")) json-spans)
    ) ;check-true
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "DecVal")) json-spans)
    ) ;check-true
  ) ;let

  ;; Lua 代码块：包含 Keyword
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Keyword")) (car (list-ref res 15)))
  ) ;check-true

  ;; 无语言代码块：内容包含 Code
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Code")) (car (list-ref res 19)))
  ) ;check-true
) ;let*

;; Bash 结构高亮测试
(let* ((bashdef (load-syntax-definition "bash"))
       (code "#!/usr/bin/env bash\n# comment\nset -euo pipefail\nNAME=${1:-world}\nif [ -f \"$NAME\" ]; then\n  echo \"hello $NAME\"\nfi\n"
       ) ;code
       (res (highlight-text code bashdef))
      ) ;
  (check (> (length res) 6) => #t)
  ;; 第一行 shebang 是 Comment
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Comment")) (caar res))
  ) ;check-true
  ;; 第四行包含 Variable 与 Operator
  (let ((line4-spans (car (list-ref res 3))))
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "Variable")) line4-spans)
    ) ;check-true
    (check-true
      (any (lambda (sp) (string=? (caddr sp) "Operator")) line4-spans)
    ) ;check-true
  ) ;let
  ;; 第五行包含 ControlFlow
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "ControlFlow")) (car (list-ref res 4)))
  ) ;check-true
) ;let*

;; Markdown 中的 Bash 代码块嵌套高亮
(let* ((mddef (load-syntax-definition "markdown"))
       (doc (string-append "```bash\n" "if [ -n \"$HOME\" ]; then\n"
              "  echo \"$HOME\"\n" "fi\n" "```\n"
            ) ;string-append
       ) ;doc
       (res (highlight-text doc mddef))
      ) ;
  ;; 围栏行标记 Fenced Code
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Fenced Code")) (caar res))
  ) ;check-true
  ;; 第二行按 Bash 规则高亮出 ControlFlow
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "ControlFlow")) (caadr res))
  ) ;check-true
  ;; 第三行包含 Variable
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Variable")) (car (list-ref res 2)))
  ) ;check-true
) ;let*

;; Markdown 中的 Diff 代码块嵌套高亮
(let* ((mddef (load-syntax-definition "markdown"))
       (doc (string-append "```diff\n" "+ added line\n" "- removed line\n" "```\n"))
       (res (highlight-text doc mddef))
      ) ;
  ;; 围栏行标记 Fenced Code
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Fenced Code")) (caar res))
  ) ;check-true
  ;; 第二行按 Diff 规则高亮出 Added
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Added")) (caadr res))
  ) ;check-true
  ;; 第三行按 Diff 规则高亮出 Removed
  (check-true
    (any (lambda (sp) (string=? (caddr sp) "Removed")) (car (list-ref res 2)))
  ) ;check-true
) ;let*

(check-report)
