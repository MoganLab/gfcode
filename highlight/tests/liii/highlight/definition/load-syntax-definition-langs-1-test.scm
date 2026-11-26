;; load-syntax-definition
;; 各语法定义的上下文与样式别名回归测试（第一批：JSON/C/C++/Lua/Markdown/Bash/JavaScript/Python）。
;;
;; 语法
;; ----
;; (load-syntax-definition name)
;;
;; 参数
;; ----
;; name : string
;; 语言标识（大小写不敏感）。
;;
;; 返回值
;; ----
;; <definition>
;; 解析后的语法定义对象。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(let ((def-json (load-syntax-definition "json"))
      (def-cpp (load-syntax-definition "cpp"))
      (def-c (load-syntax-definition "c"))
      (def-lua (load-syntax-definition "lua"))
      (def-md (load-syntax-definition "markdown"))
      (def-bash (load-syntax-definition "bash"))
      (def-js (load-syntax-definition "javascript"))
      (def-py (load-syntax-definition "python"))
     ) ;
  ;; JSON 上下文与样式别名
  (check-true (not (not (definition-find-context def-json "Normal"))))
  (check-true (not (not (definition-find-context def-json "Pair"))))
  (check-true (not (not (definition-find-context def-json "String_Key"))))
  (check-true (not (not (definition-find-context def-json "String_Key_Char"))))
  (check-true (not (not (definition-find-context def-json "Value"))))
  (check-true (not (not (definition-find-context def-json "String_Value"))))
  (check-true (not (not (definition-find-context def-json "String_Key_Value"))))
  (check-true (not (not (definition-find-context def-json "Array"))))
  (check (definition-item-data-def-style def-json "Style_Normal") => "Normal")
  (check (definition-item-data-def-style def-json "Style_Seperator_Pair")
    =>
    "Function"
  ) ;check
  (check (definition-item-data-def-style def-json "Style_Seperator_Array")
    =>
    "Others"
  ) ;check
  (check (definition-item-data-def-style def-json "Style_Decimal") => "DecVal")
  (check (definition-item-data-def-style def-json "Style_Float") => "Float")
  (check (definition-item-data-def-style def-json "Style_String_Key")
    =>
    "DataType"
  ) ;check
  (check (definition-item-data-def-style def-json "Style_String_Value")
    =>
    "String"
  ) ;check
  (check (definition-item-data-def-style def-json "Style_String_Key_Char")
    =>
    "Char"
  ) ;check
  (check (definition-item-data-def-style def-json "Style_Keyword") => "Keyword")
  (check (definition-item-data-def-style def-json "Style_Error") => "Error")
  (check-true
    (> (length (context-def-rules (definition-find-context def-json "Normal"))) 0)
  ) ;check-true

  ;; C++ 上下文与样式
  (check-true (not (not (definition-find-context def-cpp "Normal"))))
  (check-true (not (not (definition-find-context def-cpp "preprocessor"))))
  (check-true (not (not (definition-find-context def-cpp "include-angle"))))
  (check-true (not (not (definition-find-context def-cpp "comment-line"))))
  (check-true (not (not (definition-find-context def-cpp "comment-block"))))
  (check-true (not (not (definition-find-context def-cpp "string"))))
  (check-true (not (not (definition-find-context def-cpp "char"))))
  (check-true (not (not (definition-find-context def-cpp "raw-string"))))
  (check (definition-item-data-def-style def-cpp "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-cpp "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-cpp "DataType") => "DataType")
  (check (definition-item-data-def-style def-cpp "Preprocessor")
    =>
    "Preprocessor"
  ) ;check
  (check (definition-item-data-def-style def-cpp "Comment") => "Comment")
  (check (definition-item-data-def-style def-cpp "String") => "String")
  (check (definition-item-data-def-style def-cpp "Char") => "Char")
  (check (definition-item-data-def-style def-cpp "BaseN") => "BaseN")

  ;; C 上下文与样式
  (check-true (not (not (definition-find-context def-c "Normal"))))
  (check-true (not (not (definition-find-context def-c "preprocessor"))))
  (check-true (not (not (definition-find-context def-c "include-angle"))))
  (check-true (not (not (definition-find-context def-c "comment-line"))))
  (check-true (not (not (definition-find-context def-c "comment-block"))))
  (check-true (not (not (definition-find-context def-c "string"))))
  (check-true (not (not (definition-find-context def-c "char"))))
  (check (definition-item-data-def-style def-c "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-c "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-c "DataType") => "DataType")
  (check (definition-item-data-def-style def-c "Preprocessor") => "Preprocessor")
  (check (definition-item-data-def-style def-c "Comment") => "Comment")
  (check (definition-item-data-def-style def-c "String") => "String")
  (check (definition-item-data-def-style def-c "Char") => "Char")
  (check (definition-item-data-def-style def-c "BaseN") => "BaseN")

  ;; Lua 上下文与样式
  (check-true (not (not (definition-find-context def-lua "Normal"))))
  (check-true (not (not (definition-find-context def-lua "shebang"))))
  (check-true (not (not (definition-find-context def-lua "comment-line"))))
  (check-true (not (not (definition-find-context def-lua "comment-block"))))
  (check-true (not (not (definition-find-context def-lua "comment-block-eq1"))))
  (check-true (not (not (definition-find-context def-lua "comment-block-eq2"))))
  (check-true (not (not (definition-find-context def-lua "raw-string"))))
  (check-true (not (not (definition-find-context def-lua "raw-string-eq1"))))
  (check-true (not (not (definition-find-context def-lua "raw-string-eq2"))))
  (check-true (not (not (definition-find-context def-lua "string-double"))))
  (check-true (not (not (definition-find-context def-lua "string-single"))))
  (check (definition-item-data-def-style def-lua "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-lua "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-lua "Constant") => "Constant")
  (check (definition-item-data-def-style def-lua "Function") => "Function")
  (check (definition-item-data-def-style def-lua "BuiltIn") => "BuiltIn")
  (check (definition-item-data-def-style def-lua "Variable") => "Variable")
  (check (definition-item-data-def-style def-lua "Comment") => "Comment")
  (check (definition-item-data-def-style def-lua "String") => "String")
  (check (definition-item-data-def-style def-lua "VerbatimString")
    =>
    "VerbatimString"
  ) ;check
  (check (definition-item-data-def-style def-lua "SpecialChar") => "SpecialChar")

  ;; Markdown 上下文与样式
  (check-true (not (not (definition-find-context def-md "Normal"))))
  (check-true (not (not (definition-find-context def-md "header-1"))))
  (check-true (not (not (definition-find-context def-md "header-2"))))
  (check-true (not (not (definition-find-context def-md "header-3"))))
  (check-true (not (not (definition-find-context def-md "blockquote"))))
  (check-true (not (not (definition-find-context def-md "inline-code-single"))))
  (check-true (not (not (definition-find-context def-md "comment"))))
  (check (definition-item-data-def-style def-md "Header") => "Function")
  (check (definition-item-data-def-style def-md "Header H1") => "Function")
  (check (definition-item-data-def-style def-md "Blockquote") => "Attribute")
  (check (definition-item-data-def-style def-md "List") => "SpecialString")
  (check (definition-item-data-def-style def-md "Table") => "Preprocessor")
  (check (definition-item-data-def-style def-md "Code") => "Information")
  (check (definition-item-data-def-style def-md "Fenced Code") => "Information")
  (check (definition-item-data-def-style def-md "Link") => "Others")
  (check (definition-item-data-def-style def-md "Comment") => "Comment")

  ;; Bash 上下文与样式
  (check-true (not (not (definition-find-context def-bash "Normal"))))
  (check-true (not (not (definition-find-context def-bash "shebang"))))
  (check-true (not (not (definition-find-context def-bash "comment"))))
  (check-true (not (not (definition-find-context def-bash "dollar"))))
  (check-true (not (not (definition-find-context def-bash "var-brace"))))
  (check-true (not (not (definition-find-context def-bash "subst-command"))))
  (check-true (not (not (definition-find-context def-bash "string-double"))))
  (check-true (not (not (definition-find-context def-bash "string-single"))))
  (check-true (not (not (definition-find-context def-bash "backquote"))))
  (check-true (not (not (definition-find-context def-bash "escape"))))
  (check (definition-item-data-def-style def-bash "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-bash "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-bash "Builtin") => "BuiltIn")
  (check (definition-item-data-def-style def-bash "Variable") => "Variable")
  (check (definition-item-data-def-style def-bash "Parameter Expansion")
    =>
    "Variable"
  ) ;check
  (check (definition-item-data-def-style def-bash "Operator") => "Operator")
  (check (definition-item-data-def-style def-bash "Comment") => "Comment")
  (check (definition-item-data-def-style def-bash "String") => "String")
  (check (definition-item-data-def-style def-bash "String Transl.") => "String")
  (check (definition-item-data-def-style def-bash "Backquote") => "SpecialChar")

  ;; JavaScript 上下文与样式
  (check-true (not (not (definition-find-context def-js "Normal"))))
  (check-true (not (not (definition-find-context def-js "shebang"))))
  (check-true (not (not (definition-find-context def-js "comment-line"))))
  (check-true (not (not (definition-find-context def-js "comment-block"))))
  (check-true (not (not (definition-find-context def-js "string-double"))))
  (check-true (not (not (definition-find-context def-js "string-single"))))
  (check-true (not (not (definition-find-context def-js "template"))))
  (check-true (not (not (definition-find-context def-js "substitution"))))
  (check-true (not (not (definition-find-context def-js "escape"))))
  (check-true (not (not (definition-find-context def-js "member"))))
  (check-true (not (not (definition-find-context def-js "function-name"))))
  (check (definition-item-data-def-style def-js "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-js "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-js "Module") => "Import")
  (check (definition-item-data-def-style def-js "Primitives") => "Constant")
  (check (definition-item-data-def-style def-js "Built-in Objects") => "BuiltIn")
  (check (definition-item-data-def-style def-js "Function Name") => "Function")
  (check (definition-item-data-def-style def-js "Object Member") => "Attribute")
  (check (definition-item-data-def-style def-js "Symbol") => "Operator")
  (check (definition-item-data-def-style def-js "String") => "String")
  (check (definition-item-data-def-style def-js "Template") => "VerbatimString")
  (check (definition-item-data-def-style def-js "Comment") => "Comment")

  ;; Python 上下文与样式
  (check-true (not (not (definition-find-context def-py "Normal"))))
  (check-true (not (not (definition-find-context def-py "hash-comment"))))
  (check-true (not (not (definition-find-context def-py "decorator"))))
  (check-true (not (not (definition-find-context def-py "triple-d"))))
  (check-true (not (not (definition-find-context def-py "triple-s"))))
  (check-true (not (not (definition-find-context def-py "raw-string-d"))))
  (check-true (not (not (definition-find-context def-py "raw-string-s"))))
  (check-true (not (not (definition-find-context def-py "f-string-d"))))
  (check-true (not (not (definition-find-context def-py "f-string-s"))))
  (check-true (not (not (definition-find-context def-py "string-d"))))
  (check-true (not (not (definition-find-context def-py "string-s"))))
  (check (definition-item-data-def-style def-py "Flow Control Keyword")
    =>
    "ControlFlow"
  ) ;check
  (check (definition-item-data-def-style def-py "Operator Keyword") => "Keyword")
  (check (definition-item-data-def-style def-py "Builtin Function") => "BuiltIn")
  (check (definition-item-data-def-style def-py "Import") => "Import")
  (check (definition-item-data-def-style def-py "Overloaders") => "Function")
  (check (definition-item-data-def-style def-py "Special Variable") => "Constant")
  (check (definition-item-data-def-style def-py "Decorator") => "Attribute")
  (check (definition-item-data-def-style def-py "String") => "String")
  (check (definition-item-data-def-style def-py "Raw String") => "VerbatimString")
  (check (definition-item-data-def-style def-py "F-String") => "SpecialString")
  (check (definition-item-data-def-style def-py "Comment") => "Comment")
  (check (definition-item-data-def-style def-py "Hex") => "BaseN")
  (check (definition-item-data-def-style def-py "Float") => "Float")
  (check (definition-item-data-def-style def-py "Int") => "DecVal")
) ;let

(check-report)
