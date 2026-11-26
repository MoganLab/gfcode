;; load-syntax-definition
;; 各语法定义的上下文与样式别名回归测试（第二批：Rust/TypeScript/YAML/TOML/SQL/Ruby/PHP/Kotlin）。
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

(let ((def-rs (load-syntax-definition "rust"))
      (def-ts (load-syntax-definition "typescript"))
      (def-yaml (load-syntax-definition "yaml"))
      (def-toml (load-syntax-definition "toml"))
      (def-sql (load-syntax-definition "sql"))
      (def-rb (load-syntax-definition "ruby"))
      (def-php (load-syntax-definition "php"))
      (def-kt (load-syntax-definition "kotlin"))
     ) ;
  ;; Rust 上下文与样式
  (check-true (not (not (definition-find-context def-rs "Normal"))))
  (check-true (not (not (definition-find-context def-rs "Function"))))
  (check-true (not (not (definition-find-context def-rs "Type"))))
  (check-true (not (not (definition-find-context def-rs "attribute"))))
  (check-true (not (not (definition-find-context def-rs "string"))))
  (check-true (not (not (definition-find-context def-rs "byte-string"))))
  (check-true (not (not (definition-find-context def-rs "raw-string"))))
  (check-true (not (not (definition-find-context def-rs "character"))))
  (check-true (not (not (definition-find-context def-rs "comment-line"))))
  (check-true (not (not (definition-find-context def-rs "comment-block"))))
  (check (definition-item-data-def-style def-rs "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-rs "Control Flow") => "ControlFlow")
  (check (definition-item-data-def-style def-rs "Type") => "DataType")
  (check (definition-item-data-def-style def-rs "CType") => "DataType")
  (check (definition-item-data-def-style def-rs "Trait") => "BuiltIn")
  (check (definition-item-data-def-style def-rs "Constant") => "Constant")
  (check (definition-item-data-def-style def-rs "Comment") => "Comment")
  (check (definition-item-data-def-style def-rs "Number") => "DecVal")
  (check (definition-item-data-def-style def-rs "String") => "String")
  (check (definition-item-data-def-style def-rs "CharEscape") => "SpecialChar")
  (check (definition-item-data-def-style def-rs "Character") => "Char")
  (check (definition-item-data-def-style def-rs "Macro") => "Preprocessor")
  (check (definition-item-data-def-style def-rs "Symbol") => "Operator")
  (check (definition-item-data-def-style def-rs "Attribute") => "Attribute")
  (check (definition-item-data-def-style def-rs "Lifetime") => "Others")

  ;; TypeScript 上下文与样式
  (check-true (not (not (definition-find-context def-ts "Normal"))))
  (check-true (not (not (definition-find-context def-ts "shebang"))))
  (check-true (not (not (definition-find-context def-ts "decorator"))))
  (check-true (not (not (definition-find-context def-ts "comment-line"))))
  (check-true (not (not (definition-find-context def-ts "comment-block"))))
  (check-true (not (not (definition-find-context def-ts "string-double"))))
  (check-true (not (not (definition-find-context def-ts "string-single"))))
  (check-true (not (not (definition-find-context def-ts "template"))))
  (check-true (not (not (definition-find-context def-ts "substitution"))))
  (check-true (not (not (definition-find-context def-ts "escape"))))
  (check-true (not (not (definition-find-context def-ts "member"))))
  (check-true (not (not (definition-find-context def-ts "function-name"))))
  (check (definition-item-data-def-style def-ts "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-ts "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-ts "Reserved") => "Keyword")
  (check (definition-item-data-def-style def-ts "Module") => "Import")
  (check (definition-item-data-def-style def-ts "Primitives") => "Constant")
  (check (definition-item-data-def-style def-ts "DataType") => "DataType")
  (check (definition-item-data-def-style def-ts "Built-in Objects") => "BuiltIn")
  (check (definition-item-data-def-style def-ts "Function Name") => "Function")
  (check (definition-item-data-def-style def-ts "Function Declaration")
    =>
    "Function"
  ) ;check
  (check (definition-item-data-def-style def-ts "Object Member") => "Attribute")
  (check (definition-item-data-def-style def-ts "Decorator") => "Attribute")
  (check (definition-item-data-def-style def-ts "Symbol") => "Operator")
  (check (definition-item-data-def-style def-ts "Template") => "VerbatimString")
  (check (definition-item-data-def-style def-ts "Comment") => "Comment")

  ;; YAML 上下文与样式
  (check-true (not (not (definition-find-context def-yaml "normal"))))
  (check-true (not (not (definition-find-context def-yaml "key"))))
  (check-true (not (not (definition-find-context def-yaml "value"))))
  (check-true (not (not (definition-find-context def-yaml "list"))))
  (check-true (not (not (definition-find-context def-yaml "hash"))))
  (check-true (not (not (definition-find-context def-yaml "string-sq"))))
  (check-true (not (not (definition-find-context def-yaml "string-dq"))))
  (check-true (not (not (definition-find-context def-yaml "block-operator"))))
  (check-true (not (not (definition-find-context def-yaml "comment"))))
  (check-true (not (not (definition-find-context def-yaml "directive"))))
  (check-true (not (not (definition-find-context def-yaml "tag"))))
  (check-true (not (not (definition-find-context def-yaml "alias"))))
  (check-true (not (not (definition-find-context def-yaml "reference"))))
  (check (definition-item-data-def-style def-yaml "Key") => "Function")
  (check (definition-item-data-def-style def-yaml "Key Points Operator")
    =>
    "Keyword"
  ) ;check
  (check (definition-item-data-def-style def-yaml "Operator") => "Keyword")
  (check (definition-item-data-def-style def-yaml "Comment") => "Comment")
  (check (definition-item-data-def-style def-yaml "End of Document") => "Comment")
  (check (definition-item-data-def-style def-yaml "Document Header")
    =>
    "Preprocessor"
  ) ;check
  (check (definition-item-data-def-style def-yaml "Directive") => "Preprocessor")
  (check (definition-item-data-def-style def-yaml "String") => "String")
  (check (definition-item-data-def-style def-yaml "Escaped Character")
    =>
    "SpecialChar"
  ) ;check
  (check (definition-item-data-def-style def-yaml "Literal/Folded Operator")
    =>
    "Char"
  ) ;check
  (check (definition-item-data-def-style def-yaml "Integer") => "DecVal")
  (check (definition-item-data-def-style def-yaml "Float") => "Float")
  (check (definition-item-data-def-style def-yaml "Boolean") => "Char")
  (check (definition-item-data-def-style def-yaml "Null") => "Char")
  (check (definition-item-data-def-style def-yaml "Tag") => "Others")
  (check (definition-item-data-def-style def-yaml "Alias") => "Others")
  (check (definition-item-data-def-style def-yaml "Reference") => "Others")

  ;; TOML 上下文与样式
  (check-true (not (not (definition-find-context def-toml "Toml"))))
  (check-true (not (not (definition-find-context def-toml "TableHeader"))))
  (check-true (not (not (definition-find-context def-toml "NestedTableHeader"))))
  (check-true (not (not (definition-find-context def-toml "Value"))))
  (check-true (not (not (definition-find-context def-toml "Comment"))))
  (check-true (not (not (definition-find-context def-toml "QuotedKey"))))
  (check-true (not (not (definition-find-context def-toml "LitQuotedKey"))))
  (check-true (not (not (definition-find-context def-toml "String"))))
  (check-true (not (not (definition-find-context def-toml "MultilineString"))))
  (check-true (not (not (definition-find-context def-toml "LitString"))))
  (check-true (not (not (definition-find-context def-toml "LitMultilineString"))))
  (check-true (not (not (definition-find-context def-toml "Array"))))
  (check-true (not (not (definition-find-context def-toml "InArray"))))
  (check-true (not (not (definition-find-context def-toml "InlineTable"))))
  (check (definition-item-data-def-style def-toml "Key") => "DataType")
  (check (definition-item-data-def-style def-toml "TableHeader") => "Keyword")
  (check (definition-item-data-def-style def-toml "Assignment") => "Operator")
  (check (definition-item-data-def-style def-toml "Comment") => "Comment")
  (check (definition-item-data-def-style def-toml "Int") => "DecVal")
  (check (definition-item-data-def-style def-toml "Float") => "Float")
  (check (definition-item-data-def-style def-toml "Boolean true") => "Constant")
  (check (definition-item-data-def-style def-toml "Boolean false") => "Constant")
  (check (definition-item-data-def-style def-toml "String") => "String")
  (check (definition-item-data-def-style def-toml "LitString")
    =>
    "VerbatimString"
  ) ;check
  (check (definition-item-data-def-style def-toml "Escape") => "SpecialChar")
  (check (definition-item-data-def-style def-toml "Array") => "Operator")
  (check (definition-item-data-def-style def-toml "InlineTable") => "Operator")

  ;; SQL 上下文与样式
  (check-true (not (not (definition-find-context def-sql "Normal"))))
  (check-true (not (not (definition-find-context def-sql "comment-line"))))
  (check-true (not (not (definition-find-context def-sql "comment-block"))))
  (check-true (not (not (definition-find-context def-sql "string"))))
  (check-true (not (not (definition-find-context def-sql "user-identifier"))))
  (check (definition-item-data-def-style def-sql "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-sql "ControlFlow") => "ControlFlow")
  (check (definition-item-data-def-style def-sql "Operator Keyword") => "Keyword")
  (check (definition-item-data-def-style def-sql "Function") => "Function")
  (check (definition-item-data-def-style def-sql "Data Type") => "DataType")
  (check (definition-item-data-def-style def-sql "Comment") => "Comment")
  (check (definition-item-data-def-style def-sql "String") => "String")
  (check (definition-item-data-def-style def-sql "String Char") => "Char")
  (check (definition-item-data-def-style def-sql "Decimal") => "DecVal")
  (check (definition-item-data-def-style def-sql "Hex") => "BaseN")
  (check (definition-item-data-def-style def-sql "Float") => "Float")
  (check (definition-item-data-def-style def-sql "Identifier") => "Others")
  (check (definition-item-data-def-style def-sql "Preprocessor") => "Others")

  ;; Ruby 上下文与样式
  (check-true (not (not (definition-find-context def-rb "Ruby"))))
  (check-true (not (not (definition-find-context def-rb "shebang"))))
  (check-true (not (not (definition-find-context def-rb "comment"))))
  (check-true (not (not (definition-find-context def-rb "embedded-doc"))))
  (check-true (not (not (definition-find-context def-rb "dquote"))))
  (check-true (not (not (definition-find-context def-rb "squote"))))
  (check-true (not (not (definition-find-context def-rb "command"))))
  (check-true (not (not (definition-find-context def-rb "symbol"))))
  (check-true (not (not (definition-find-context def-rb "symbol-quoted"))))
  (check-true (not (not (definition-find-context def-rb "subst"))))
  (check-true (not (not (definition-find-context def-rb "member"))))
  (check (definition-item-data-def-style def-rb "Keyword") => "ControlFlow")
  (check (definition-item-data-def-style def-rb "Definition") => "Keyword")
  (check (definition-item-data-def-style def-rb "Access Control") => "Attribute")
  (check (definition-item-data-def-style def-rb "Attribute Definition")
    =>
    "Others"
  ) ;check
  (check (definition-item-data-def-style def-rb "Pseudo variable") => "DecVal")
  (check (definition-item-data-def-style def-rb "Kernel methods") => "Function")
  (check (definition-item-data-def-style def-rb "Module mixin methods")
    =>
    "Function"
  ) ;check
  (check (definition-item-data-def-style def-rb "Comment") => "Comment")
  (check (definition-item-data-def-style def-rb "Blockcomment") => "Comment")
  (check (definition-item-data-def-style def-rb "String") => "String")
  (check (definition-item-data-def-style def-rb "Raw String") => "VerbatimString")
  (check (definition-item-data-def-style def-rb "Command") => "Information")
  (check (definition-item-data-def-style def-rb "Symbol") => "Warning")
  (check (definition-item-data-def-style def-rb "Substitution") => "SpecialChar")
  (check (definition-item-data-def-style def-rb "Member") => "Attribute")

  ;; PHP 上下文与样式
  (check-true (not (not (definition-find-context def-php "start"))))
  (check-true (not (not (definition-find-context def-php "phpsource"))))
  (check-true (not (not (definition-find-context def-php "attribute"))))
  (check-true (not (not (definition-find-context def-php "comment-line"))))
  (check-true (not (not (definition-find-context def-php "comment-block"))))
  (check-true (not (not (definition-find-context def-php "string-double"))))
  (check-true (not (not (definition-find-context def-php "string-single"))))
  (check-true (not (not (definition-find-context def-php "backtick"))))
  (check (definition-item-data-def-style def-php "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-php "Control Structures")
    =>
    "ControlFlow"
  ) ;check
  (check (definition-item-data-def-style def-php "Function") => "Function")
  (check (definition-item-data-def-style def-php "Special method") => "BuiltIn")
  (check (definition-item-data-def-style def-php "Classes") => "BuiltIn")
  (check (definition-item-data-def-style def-php "Attribute") => "Attribute")
  (check (definition-item-data-def-style def-php "Types") => "DataType")
  (check (definition-item-data-def-style def-php "Properties") => "DataType")
  (check (definition-item-data-def-style def-php "Constant") => "Constant")
  (check (definition-item-data-def-style def-php "Library Constant")
    =>
    "Constant"
  ) ;check
  (check (definition-item-data-def-style def-php "Special Variable")
    =>
    "Variable"
  ) ;check
  (check (definition-item-data-def-style def-php "Variable") => "Variable")
  (check (definition-item-data-def-style def-php "Comment") => "Comment")
  (check (definition-item-data-def-style def-php "String") => "String")
  (check (definition-item-data-def-style def-php "Heredoc") => "SpecialString")
  (check (definition-item-data-def-style def-php "Nowdoc") => "VerbatimString")
  (check (definition-item-data-def-style def-php "Decimal") => "DecVal")
  (check (definition-item-data-def-style def-php "Hex") => "BaseN")
  (check (definition-item-data-def-style def-php "Float") => "Float")
  (check (definition-item-data-def-style def-php "Operator") => "Operator")
  (check (definition-item-data-def-style def-php "Error Control Operator")
    =>
    "Preprocessor"
  ) ;check

  ;; Kotlin 上下文与样式
  (check-true (not (not (definition-find-context def-kt "Normal"))))
  (check-true (not (not (definition-find-context def-kt "shebang"))))
  (check-true (not (not (definition-find-context def-kt "annotation"))))
  (check-true (not (not (definition-find-context def-kt "comment-line"))))
  (check-true (not (not (definition-find-context def-kt "comment-block"))))
  (check-true (not (not (definition-find-context def-kt "string"))))
  (check-true (not (not (definition-find-context def-kt "string-multiline"))))
  (check-true (not (not (definition-find-context def-kt "interp-expr"))))
  (check-true (not (not (definition-find-context def-kt "interp-var"))))
  (check-true (not (not (definition-find-context def-kt "char"))))
  (check-true (not (not (definition-find-context def-kt "member"))))
  (check (definition-item-data-def-style def-kt "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-kt "ControlFlowKeyword")
    =>
    "ControlFlow"
  ) ;check
  (check (definition-item-data-def-style def-kt "Function") => "Function")
  (check (definition-item-data-def-style def-kt "Variable") => "Variable")
  (check (definition-item-data-def-style def-kt "Imports") => "Import")
  (check (definition-item-data-def-style def-kt "Annotation") => "Attribute")
  (check (definition-item-data-def-style def-kt "Data Type") => "DataType")
  (check (definition-item-data-def-style def-kt "Comment") => "Comment")
  (check (definition-item-data-def-style def-kt "String") => "String")
  (check (definition-item-data-def-style def-kt "String Char") => "SpecialChar")
  (check (definition-item-data-def-style def-kt "String Interpolation")
    =>
    "SpecialString"
  ) ;check
  (check (definition-item-data-def-style def-kt "Char") => "Char")
  (check (definition-item-data-def-style def-kt "Decimal") => "DecVal")
  (check (definition-item-data-def-style def-kt "Hex") => "BaseN")
  (check (definition-item-data-def-style def-kt "Float") => "Float")
  (check (definition-item-data-def-style def-kt "Symbol") => "Operator")
) ;let

(check-report)
