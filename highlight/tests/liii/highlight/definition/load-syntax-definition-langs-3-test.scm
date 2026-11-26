;; load-syntax-definition
;; 各语法定义的上下文与样式别名回归测试（第三批：Swift/Vue/CMake/Nix/BibTeX/LaTeX/Haskell）。
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

(let ((def-swift (load-syntax-definition "swift"))
      (def-vue (load-syntax-definition "vue"))
      (def-cmake (load-syntax-definition "cmake"))
      (def-nix (load-syntax-definition "nix"))
      (def-bib (load-syntax-definition "bibtex"))
      (def-tex (load-syntax-definition "latex"))
      (def-hs (load-syntax-definition "haskell"))
     ) ;
  ;; Swift 上下文与样式
  (check-true (not (not (definition-find-context def-swift "Normal"))))
  (check-true (not (not (definition-find-context def-swift "shebang"))))
  (check-true (not (not (definition-find-context def-swift "annotation"))))
  (check-true (not (not (definition-find-context def-swift "comment-line"))))
  (check-true (not (not (definition-find-context def-swift "comment-block"))))
  (check-true (not (not (definition-find-context def-swift "string"))))
  (check-true (not (not (definition-find-context def-swift "string-multiline"))))
  (check-true (not (not (definition-find-context def-swift "interp-expr"))))
  (check-true (not (not (definition-find-context def-swift "char"))))
  (check-true (not (not (definition-find-context def-swift "member"))))
  (check (definition-item-data-def-style def-swift "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-swift "ControlFlowKeyword")
    =>
    "ControlFlow"
  ) ;check
  (check (definition-item-data-def-style def-swift "Function") => "Function")
  (check (definition-item-data-def-style def-swift "Variable") => "Variable")
  (check (definition-item-data-def-style def-swift "Imports") => "Import")
  (check (definition-item-data-def-style def-swift "Annotation") => "Attribute")
  (check (definition-item-data-def-style def-swift "Data Type") => "DataType")
  (check (definition-item-data-def-style def-swift "Comment") => "Comment")
  (check (definition-item-data-def-style def-swift "String") => "String")
  (check (definition-item-data-def-style def-swift "String Char")
    =>
    "SpecialChar"
  ) ;check
  (check (definition-item-data-def-style def-swift "String Interpolation")
    =>
    "SpecialString"
  ) ;check
  (check (definition-item-data-def-style def-swift "Char") => "Char")
  (check (definition-item-data-def-style def-swift "Decimal") => "DecVal")
  (check (definition-item-data-def-style def-swift "Hex") => "BaseN")
  (check (definition-item-data-def-style def-swift "Float") => "Float")
  (check (definition-item-data-def-style def-swift "Symbol") => "Operator")

  ;; Vue 上下文与样式（复用 IncludeRules 跨语言嵌入 CSS/JavaScript）
  (check-true (not (not (definition-find-context def-vue "Normal"))))
  (check-true (not (not (definition-find-context def-vue "comment"))))
  (check-true (not (not (definition-find-context def-vue "doctype"))))
  (check-true (not (not (definition-find-context def-vue "entity"))))
  (check-true (not (not (definition-find-context def-vue "interp"))))
  (check-true (not (not (definition-find-context def-vue "tag-open"))))
  (check-true (not (not (definition-find-context def-vue "tag-close"))))
  (check-true (not (not (definition-find-context def-vue "tag-attrs"))))
  (check-true (not (not (definition-find-context def-vue "binding-name"))))
  (check-true (not (not (definition-find-context def-vue "style-css"))))
  (check-true (not (not (definition-find-context def-vue "script-js"))))
  (check (definition-item-data-def-style def-vue "Tag") => "Keyword")
  (check (definition-item-data-def-style def-vue "TagClose") => "Keyword")
  (check (definition-item-data-def-style def-vue "AttributeName") => "Attribute")
  (check (definition-item-data-def-style def-vue "Binding") => "Function")
  (check (definition-item-data-def-style def-vue "Interpolation")
    =>
    "SpecialString"
  ) ;check
  (check (definition-item-data-def-style def-vue "InterpolationSymbol")
    =>
    "Operator"
  ) ;check
  (check (definition-item-data-def-style def-vue "Value") => "String")
  (check (definition-item-data-def-style def-vue "Comment") => "Comment")
  (check (definition-item-data-def-style def-vue "EntityRef") => "DecVal")
  (check (definition-item-data-def-style def-vue "Symbol") => "Operator")

  ;; CMake 上下文与样式
  (check-true (not (not (definition-find-context def-cmake "Normal Text"))))
  (check-true (not (not (definition-find-context def-cmake "comment"))))
  (check-true (not (not (definition-find-context def-cmake "string"))))
  (check-true (not (not (definition-find-context def-cmake "var-subst"))))
  (check-true (not (not (definition-find-context def-cmake "cache-var-subst"))))
  (check-true (not (not (definition-find-context def-cmake "env-var-subst"))))
  (check-true (not (not (definition-find-context def-cmake "genexpr"))))
  (check (definition-item-data-def-style def-cmake "Command") => "Keyword")
  (check (definition-item-data-def-style def-cmake "Control Flow")
    =>
    "ControlFlow"
  ) ;check
  (check (definition-item-data-def-style def-cmake "CMake Provided Function/Macro")
    =>
    "Function"
  ) ;check
  (check (definition-item-data-def-style def-cmake "User Function/Macro")
    =>
    "Function"
  ) ;check
  (check (definition-item-data-def-style def-cmake "Comment") => "Comment")
  (check (definition-item-data-def-style def-cmake "Strings") => "String")
  (check (definition-item-data-def-style def-cmake "Escapes") => "SpecialChar")
  (check (definition-item-data-def-style def-cmake "Builtin Variable")
    =>
    "DecVal"
  ) ;check
  (check (definition-item-data-def-style def-cmake "CMake Internal Variable")
    =>
    "Variable"
  ) ;check
  (check (definition-item-data-def-style def-cmake "Internal Name") => "Variable")
  (check (definition-item-data-def-style def-cmake "Variable Substitution")
    =>
    "DecVal"
  ) ;check
  (check (definition-item-data-def-style def-cmake "@Variable Substitution")
    =>
    "BaseN"
  ) ;check
  (check (definition-item-data-def-style def-cmake "Cache Variable Substitution")
    =>
    "Float"
  ) ;check
  (check (definition-item-data-def-style def-cmake "Environment Variable Substitution")
    =>
    "Float"
  ) ;check
  (check (definition-item-data-def-style def-cmake "Generator Expression")
    =>
    "Others"
  ) ;check

  ;; Nix 上下文与样式
  (check-true (not (not (definition-find-context def-nix "Expression"))))
  (check-true (not (not (definition-find-context def-nix "comment"))))
  (check-true (not (not (definition-find-context def-nix "block-comment"))))
  (check-true (not (not (definition-find-context def-nix "string"))))
  (check-true (not (not (definition-find-context def-nix "string2"))))
  (check-true (not (not (definition-find-context def-nix "interp"))))
  (check-true (not (not (definition-find-context def-nix "any-brace"))))
  (check-true (not (not (definition-find-context def-nix "set"))))
  (check-true (not (not (definition-find-context def-nix "set-value"))))
  (check-true (not (not (definition-find-context def-nix "list"))))
  (check-true (not (not (definition-find-context def-nix "paren"))))
  (check-true (not (not (definition-find-context def-nix "let-expr"))))
  (check-true (not (not (definition-find-context def-nix "if-expr"))))
  (check-true (not (not (definition-find-context def-nix "then-expr"))))
  (check-true (not (not (definition-find-context def-nix "with-expr"))))
  (check-true (not (not (definition-find-context def-nix "assert-expr"))))
  (check (definition-item-data-def-style def-nix "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-nix "Builtin") => "BuiltIn")
  (check (definition-item-data-def-style def-nix "Constant") => "Constant")
  (check (definition-item-data-def-style def-nix "Comment") => "Comment")
  (check (definition-item-data-def-style def-nix "String") => "String")
  (check (definition-item-data-def-style def-nix "Special Char") => "SpecialChar")
  (check (definition-item-data-def-style def-nix "Int") => "DecVal")
  (check (definition-item-data-def-style def-nix "Float") => "Float")
  (check (definition-item-data-def-style def-nix "Identifier") => "Variable")
  (check (definition-item-data-def-style def-nix "Symbol") => "Operator")
  (check (definition-item-data-def-style def-nix "Operator") => "Operator")
  (check (definition-item-data-def-style def-nix "Path") => "SpecialString")

  ;; BibTeX 上下文与样式
  (check-true (not (not (definition-find-context def-bib "Normal"))))
  (check-true (not (not (definition-find-context def-bib "Entry"))))
  (check-true (not (not (definition-find-context def-bib "Field"))))
  (check-true (not (not (definition-find-context def-bib "CurlyBracket"))))
  (check-true (not (not (definition-find-context def-bib "QuotedText"))))
  (check-true (not (not (definition-find-context def-bib "StringCommand"))))
  (check-true (not (not (definition-find-context def-bib "PreambleCommand"))))
  (check-true (not (not (definition-find-context def-bib "latex-cmd"))))
  (check (definition-item-data-def-style def-bib "Entry") => "Variable")
  (check (definition-item-data-def-style def-bib "Command") => "Function")
  (check (definition-item-data-def-style def-bib "Field") => "DataType")
  (check (definition-item-data-def-style def-bib "Ref Key") => "Others")
  (check (definition-item-data-def-style def-bib "LatexCommand") => "Char")
  (check (definition-item-data-def-style def-bib "Comment") => "Comment")
  (check (definition-item-data-def-style def-bib "String") => "String")
  (check (definition-item-data-def-style def-bib "Error") => "Error")

  ;; LaTeX 上下文与样式
  (check-true (not (not (definition-find-context def-tex "Normal Text"))))
  (check-true (not (not (definition-find-context def-tex "LatexMacro"))))
  (check-true (not (not (definition-find-context def-tex "ContrSeq"))))
  (check-true (not (not (definition-find-context def-tex "Comment"))))
  (check-true (not (not (definition-find-context def-tex "FindBeginEnvironment")))
  ) ;check-true
  (check-true (not (not (definition-find-context def-tex "FindEndEnvironment"))))
  (check-true (not (not (definition-find-context def-tex "Verbatim"))))
  (check-true (not (not (definition-find-context def-tex "BlockComment"))))
  (check-true (not (not (definition-find-context def-tex "MathMode"))))
  (check-true (not (not (definition-find-context def-tex "MathModeDisplay"))))
  (check-true (not (not (definition-find-context def-tex "MathModeLatex"))))
  (check-true (not (not (definition-find-context def-tex "MathModeLatexEquation")))
  ) ;check-true
  (check-true (not (not (definition-find-context def-tex "MathModeEnv"))))
  (check-true (not (not (definition-find-context def-tex "Sectioning"))))
  (check-true (not (not (definition-find-context def-tex "SectioningInside"))))
  (check-true (not (not (definition-find-context def-tex "Label"))))
  (check-true (not (not (definition-find-context def-tex "LabelParameter"))))
  (check-true (not (not (definition-find-context def-tex "FancyLabel"))))
  (check-true (not (not (definition-find-context def-tex "FancyLabelParameter"))))
  (check (definition-item-data-def-style def-tex "Structure") => "Keyword")
  (check (definition-item-data-def-style def-tex "Builtin Macro") => "BuiltIn")
  (check (definition-item-data-def-style def-tex "Macro") => "Function")
  (check (definition-item-data-def-style def-tex "Macro Mathmode")
    =>
    "SpecialChar"
  ) ;check
  (check (definition-item-data-def-style def-tex "Comment") => "Comment")
  (check (definition-item-data-def-style def-tex "Math") => "SpecialString")
  (check (definition-item-data-def-style def-tex "Environment") => "Extension")
  (check (definition-item-data-def-style def-tex "Reference") => "Extension")
  (check (definition-item-data-def-style def-tex "Verbatim") => "VerbatimString")
  (check (definition-item-data-def-style def-tex "Sectioning Text") => "Normal")
  (check (definition-item-data-def-style def-tex "Sectioning Macro")
    =>
    "Function"
  ) ;check
  (check (definition-item-data-def-style def-tex "Sectioning Math")
    =>
    "SpecialString"
  ) ;check
  (check (definition-item-data-def-style def-tex "Error") => "Error")

  ;; Haskell 上下文与样式
  (check-true (not (not (definition-find-context def-hs "code"))))
  (check-true (not (not (definition-find-context def-hs "pragma"))))
  (check-true (not (not (definition-find-context def-hs "line-comment"))))
  (check-true (not (not (definition-find-context def-hs "block-comment"))))
  (check-true (not (not (definition-find-context def-hs "char"))))
  (check-true (not (not (definition-find-context def-hs "string"))))
  (check-true (not (not (definition-find-context def-hs "infix"))))
  (check-true (not (not (definition-find-context def-hs "import-ctx"))))
  (check (definition-item-data-def-style def-hs "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-hs "Type Prelude") => "DataType")
  (check (definition-item-data-def-style def-hs "Function Prelude") => "Function")
  (check (definition-item-data-def-style def-hs "Data Prelude") => "DataType")
  (check (definition-item-data-def-style def-hs "Class Prelude") => "DataType")
  (check (definition-item-data-def-style def-hs "Comment") => "Comment")
  (check (definition-item-data-def-style def-hs "Pragma") => "Others")
  (check (definition-item-data-def-style def-hs "Char") => "Char")
  (check (definition-item-data-def-style def-hs "String") => "String")
  (check (definition-item-data-def-style def-hs "Hex") => "BaseN")
  (check (definition-item-data-def-style def-hs "Float") => "Float")
  (check (definition-item-data-def-style def-hs "Decimal") => "DecVal")
  (check (definition-item-data-def-style def-hs "Operator") => "Operator")
  (check (definition-item-data-def-style def-hs "Type") => "DataType")
  (check (definition-item-data-def-style def-hs "Function Infix") => "Others")
  (check (definition-item-data-def-style def-hs "EnumFromTo") => "Others")
) ;let

(check-report)
