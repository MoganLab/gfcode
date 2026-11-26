;; highlight-line
;; 高亮单行文本。
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
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

(define (span-with-style? spans style)
  (any (lambda (sp) (string=? (caddr sp) style)) spans)
) ;define

(let ((def (load-syntax-definition "scheme")))
  ;; define 语句：识别 Extension 与 DecVal
  (let-values (((spans next-state)
                (highlight-line "(define x 42)" (initial-highlight-state def) def)
               ) ;
              ) ;
    (check-true (pair? spans))
    (check-true (span-with-style? spans "Extension"))
    (check-true (span-with-style? spans "DecVal"))
    (check (car (highlight-state-stack next-state)) => "Level0")
  ) ;let-values

  ;; 单行注释：整行 Comment 且行尾自动 pop 回 Level0
  (let-values (((spans next-state)
                (highlight-line ";; a comment" (initial-highlight-state def) def)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Comment"))
    (check (car (highlight-state-stack next-state)) => "Level0")
  ) ;let-values

  ;; 字符串跨行：行尾进入 string 上下文
  (let-values (((spans s1) (highlight-line "(display \"abc" (initial-highlight-state def) def))
              ) ;
    (check (car (highlight-state-stack s1)) => "string")
    ;; 第二行仍在字符串中
    (let-values (((spans2 s2) (highlight-line "still string" s1 def)))
      (check (car (highlight-state-stack s2)) => "string")
    ) ;let-values
  ) ;let-values

  ;; 多行注释跨行
  (let-values (((spans1 s1) (highlight-line "#| start" (initial-highlight-state def) def)))
    (check (car (highlight-state-stack s1)) => "multiline-comment")
    (let-values (((spans2 s2) (highlight-line "end |#" s1 def)))
      (check (car (highlight-state-stack s2)) => "Level0")
    ) ;let-values
  ) ;let-values

  ;; 空行：spans 为空，状态保持
  (let-values (((spans next-state) (highlight-line "" (initial-highlight-state def) def)))
    (check spans => '())
    (check (car (highlight-state-stack next-state)) => "Level0")
  ) ;let-values
) ;let

;; JSON 行级高亮测试
(let ((jdef (load-syntax-definition "json")))
  ;; 键值对：在对象内部识别 DataType、Float、Function
  (let-values (((spans next-state)
                (highlight-line "{\"key\": 3.14}" (initial-highlight-state jdef) jdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "DataType"))
    (check-true (span-with-style? spans "Float"))
    (check-true (span-with-style? spans "Function"))
  ) ;let-values

  ;; 合法与非法转义序列
  (let-values (((spans1 s1) (highlight-line "\"\\n\"" (initial-highlight-state jdef) jdef)))
    (check-true (span-with-style? spans1 "Char"))
  ) ;let-values

  (let-values (((spans2 s2) (highlight-line "\"\\a\"" (initial-highlight-state jdef) jdef)))
    (check-true (span-with-style? spans2 "Error"))
  ) ;let-values
) ;let

;; C++ 行级高亮测试
(let ((cppdef (load-syntax-definition "cpp")))
  ;; 预处理器与尖括号 include
  (let-values (((spans next-state)
                (highlight-line "#include <vector>" (initial-highlight-state cppdef) cppdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Preprocessor"))
    (check-true (span-with-style? spans "String"))
  ) ;let-values

  ;; 语句行：识别 DataType、Keyword、ControlFlow、Operator
  (let-values (((spans next-state)
                (highlight-line "int x = 42;" (initial-highlight-state cppdef) cppdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "DataType"))
    (check-true (span-with-style? spans "Operator"))
    (check-true (span-with-style? spans "DecVal"))
  ) ;let-values
) ;let

;; C 行级高亮测试
(let ((cdef (load-syntax-definition "c")))
  (let-values (((spans next-state)
                (highlight-line "static const char *s = \"hello\";"
                  (initial-highlight-state cdef)
                  cdef
                ) ;highlight-line
               ) ;
              ) ;
    (check-true (span-with-style? spans "DataType"))
    (check-true (span-with-style? spans "Operator"))
    (check-true (span-with-style? spans "String"))
  ) ;let-values
) ;let

;; Lua 行级高亮测试
(let ((luadef (load-syntax-definition "lua")))
  (let-values (((spans next-state)
                (highlight-line "local function add(a, b) return a + b end"
                  (initial-highlight-state luadef)
                  luadef
                ) ;highlight-line
               ) ;
              ) ;
    (check-true (span-with-style? spans "Keyword"))
    (check-true (span-with-style? spans "ControlFlow"))
    (check-true (span-with-style? spans "Operator"))
  ) ;let-values
) ;let

;; Markdown 行级高亮测试
(let ((mddef (load-syntax-definition "markdown")))
  ;; ATX 标题
  (let-values (((spans next-state)
                (highlight-line "# Header 1" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Header H1"))
  ) ;let-values

  (let-values (((spans next-state)
                (highlight-line "## Header 2" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Header H2"))
  ) ;let-values

  ;; 引用块
  (let-values (((spans next-state)
                (highlight-line "> a quote block" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Blockquote"))
  ) ;let-values

  ;; 列表与复选框
  (let-values (((spans next-state)
                (highlight-line "- [ ] todo task" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "List"))
  ) ;let-values

  ;; 分隔线
  (let-values (((spans next-state)
                (highlight-line "---" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Horizontal Rule"))
  ) ;let-values

  ;; 表格
  (let-values (((spans next-state)
                (highlight-line "| col1 | col2 |" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Table"))
  ) ;let-values

  ;; 行内代码
  (let-values (((spans next-state)
                (highlight-line "text `code` more" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Code"))
  ) ;let-values

  ;; 粗体
  (let-values (((spans next-state)
                (highlight-line "text **bold** more" (initial-highlight-state mddef) mddef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Strong Text"))
  ) ;let-values

  ;; 代码块起始与闭合
  (let-values (((spans1 s1) (highlight-line "```scheme" (initial-highlight-state mddef) mddef))
              ) ;
    (check-true (span-with-style? spans1 "Fenced Code"))
    ;; 代码块内部执行 Scheme 高亮
    (let-values (((spans2 s2) (highlight-line "(define x 42)" s1 mddef)))
      (check-true (span-with-style? spans2 "Extension"))
      (check-true (span-with-style? spans2 "DecVal"))
      ;; 闭合代码块
      (let-values (((spans3 s3) (highlight-line "```" s2 mddef)))
        (check-true (span-with-style? spans3 "Fenced Code"))
      ) ;let-values
    ) ;let-values
  ) ;let-values
) ;let

;; Bash 行级高亮测试
(let ((bashdef (load-syntax-definition "bash")))
  ;; 变量赋值与命令替换：识别 Variable、Operator 与 Builtin
  (let-values (((spans next-state)
                (highlight-line "local name=${USER:-world}"
                  (initial-highlight-state bashdef)
                  bashdef
                ) ;highlight-line
               ) ;
              ) ;
    (check-true (span-with-style? spans "Builtin"))
    (check-true (span-with-style? spans "Operator"))
    (check-true (span-with-style? spans "Variable"))
  ) ;let-values

  ;; 控制流关键字
  (let-values (((spans next-state)
                (highlight-line "if [ -f \"/etc/passwd\" ]; then"
                  (initial-highlight-state bashdef)
                  bashdef
                ) ;highlight-line
               ) ;
              ) ;
    (check-true (span-with-style? spans "ControlFlow"))
    (check-true (span-with-style? spans "String"))
  ) ;let-values

  ;; 注释与双引号字符串中的变量
  (let-values (((spans next-state)
                (highlight-line "echo \"hi $USER\" # greeting"
                  (initial-highlight-state bashdef)
                  bashdef
                ) ;highlight-line
               ) ;
              ) ;
    (check-true (span-with-style? spans "Builtin"))
    (check-true (span-with-style? spans "String"))
    (check-true (span-with-style? spans "Variable"))
    (check-true (span-with-style? spans "Comment"))
  ) ;let-values

  ;; 字符串跨行仍保持 String 上下文
  (let-values (((spans s1)
                (highlight-line "echo \"unterminated" (initial-highlight-state bashdef) bashdef)
               ) ;
              ) ;
    (check (car (highlight-state-stack s1)) => "string-double")
    (let-values (((spans2 s2) (highlight-line "still string\"" s1 bashdef)))
      (check (car (highlight-state-stack s2)) => "Normal")
    ) ;let-values
  ) ;let-values
) ;let


;; JavaScript 行级高亮测试
(let ((jsdef (load-syntax-definition "javascript")))
  ;; import/export 模块关键字与字符串
  (let-values (((spans next-state)
                (highlight-line "import fs from 'fs';" (initial-highlight-state jsdef) jsdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Module"))
    (check-true (span-with-style? spans "String"))
  ) ;let-values

  ;; 函数声明与控制流
  (let-values (((spans next-state)
                (highlight-line "if (a && b) { return null; }"
                  (initial-highlight-state jsdef)
                  jsdef
                ) ;highlight-line
               ) ;
              ) ;
    (check-true (span-with-style? spans "ControlFlow"))
    (check-true (span-with-style? spans "Symbol"))
    (check-true (span-with-style? spans "Primitives"))
  ) ;let-values

  ;; 函数声明识别函数名
  (let-values (((spans next-state)
                (highlight-line "function greet(name) {" (initial-highlight-state jsdef) jsdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Keyword"))
    (check-true (span-with-style? spans "Function Declaration"))
  ) ;let-values

  ;; 数字字面量与对象成员
  (let-values (((spans next-state)
                (highlight-line "const x = 0xFF + 1.5e3;" (initial-highlight-state jsdef) jsdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Hex"))
    (check-true (span-with-style? spans "Float"))
  ) ;let-values

  ;; 十进制字面量
  (let-values (((spans next-state)
                (highlight-line "const n = 42;" (initial-highlight-state jsdef) jsdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Decimal"))
  ) ;let-values

  ;; 模板字符串与替换
  (let-values (((spans next-state)
                (highlight-line "const s = `hi ${name}`;" (initial-highlight-state jsdef) jsdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Template"))
    (check-true (span-with-style? spans "Substitution"))
  ) ;let-values

  ;; 多行注释跨行
  (let-values (((spans s1) (highlight-line "/* start" (initial-highlight-state jsdef) jsdef)))
    (check (car (highlight-state-stack s1)) => "comment-block")
    (let-values (((spans2 s2) (highlight-line "end */" s1 jsdef)))
      (check (car (highlight-state-stack s2)) => "Normal")
      (check-true (span-with-style? spans2 "Comment"))
    ) ;let-values
  ) ;let-values

  ;; 点号成员访问
  (let-values (((spans next-state)
                (highlight-line "console.log(value);" (initial-highlight-state jsdef) jsdef)
               ) ;
              ) ;
    (check-true (span-with-style? spans "Built-in Objects"))
    (check-true (span-with-style? spans "Object Member"))
  ) ;let-values
) ;let

(check-report)
