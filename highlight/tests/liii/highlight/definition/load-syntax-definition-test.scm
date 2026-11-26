;; load-syntax-definition
;; 根据语言名称从 highlight/resources/syntax/<lang>.json 文件加载语法定义。
;;
;; 语法
;; ----
;; (load-syntax-definition name)
;;
;; 参数
;; ----
;; name : string
;; 语言标识，如 "c"、"cpp"、"json"、"scheme"（大小写不敏感）。
;;
;; 返回值
;; ----
;; <definition>
;; 解析后的语法定义对象。
;;
;; 说明
;; ----
;; 本文件覆盖各语言定义的名称、大小写、初始上下文、扩展名与 Scheme 上下文样式，
;; 以及每次加载返回新对象的语义。其余语言的上下文与样式别名回归测试分别在
;; load-syntax-definition-langs-1-test.scm、langs-2-test.scm、langs-3-test.scm。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(let ((def-scm (load-syntax-definition "scheme"))
      (def-json (load-syntax-definition "json"))
      (def-cpp (load-syntax-definition "cpp"))
      (def-c (load-syntax-definition "c"))
      (def-lua (load-syntax-definition "lua"))
      (def-md (load-syntax-definition "markdown"))
      (def-bash (load-syntax-definition "bash"))
      (def-js (load-syntax-definition "javascript"))
      (def-py (load-syntax-definition "python"))
      (def-rs (load-syntax-definition "rust"))
      (def-ts (load-syntax-definition "typescript"))
      (def-yaml (load-syntax-definition "yaml"))
      (def-toml (load-syntax-definition "toml"))
      (def-sql (load-syntax-definition "sql"))
      (def-rb (load-syntax-definition "ruby"))
      (def-php (load-syntax-definition "php"))
      (def-kt (load-syntax-definition "kotlin"))
      (def-swift (load-syntax-definition "swift"))
      (def-vue (load-syntax-definition "vue"))
      (def-cmake (load-syntax-definition "cmake"))
      (def-nix (load-syntax-definition "nix"))
      (def-bib (load-syntax-definition "bibtex"))
      (def-tex (load-syntax-definition "latex"))
      (def-hs (load-syntax-definition "haskell"))
     ) ;
  ;; 名称与大小写不敏感
  (check (definition? def-scm) => #t)
  (check (definition-name def-scm) => "Scheme")
  (check (definition-name (load-syntax-definition "C")) => "C")
  (check (definition-name (load-syntax-definition "BASH")) => "Bash")

  (check (definition-name def-json) => "JSON")
  (check (definition-name def-cpp) => "C++")
  (check (definition-name def-c) => "C")
  (check (definition-name def-lua) => "Lua")
  (check (definition-name def-md) => "Markdown")
  (check (definition-name def-bash) => "Bash")
  (check (definition-name def-js) => "JavaScript")
  (check (definition-name def-py) => "Python")
  (check (definition-name def-rs) => "Rust")
  (check (definition-name def-ts) => "TypeScript")
  (check (definition-name def-yaml) => "YAML")
  (check (definition-name def-toml) => "TOML")
  (check (definition-name def-sql) => "SQL")
  (check (definition-name def-rb) => "Ruby")
  (check (definition-name def-php) => "PHP")
  (check (definition-name def-kt) => "Kotlin")
  (check (definition-name def-swift) => "Swift")
  (check (definition-name def-vue) => "Vue")
  (check (definition-name def-cmake) => "CMake")
  (check (definition-name def-nix) => "Nix")
  (check (definition-name def-bib) => "BibTeX")
  (check (definition-name def-tex) => "LaTeX")
  (check (definition-name def-hs) => "Haskell")

  ;; 初始上下文
  (check (definition-initial-context-name def-scm) => "Level0")
  (check (definition-initial-context-name def-json) => "Normal")
  (check (definition-initial-context-name def-cpp) => "Normal")
  (check (definition-initial-context-name def-c) => "Normal")
  (check (definition-initial-context-name def-lua) => "Normal")
  (check (definition-initial-context-name def-md) => "Normal")
  (check (definition-initial-context-name def-bash) => "Normal")
  (check (definition-initial-context-name def-js) => "Normal")
  (check (definition-initial-context-name def-py) => "Normal")
  (check (definition-initial-context-name def-rs) => "Normal")
  (check (definition-initial-context-name def-ts) => "Normal")
  (check (definition-initial-context-name def-yaml) => "normal")
  (check (definition-initial-context-name def-toml) => "Toml")
  (check (definition-initial-context-name def-sql) => "Normal")
  (check (definition-initial-context-name def-rb) => "Ruby")
  (check (definition-initial-context-name def-php) => "start")
  (check (definition-initial-context-name def-kt) => "Normal")
  (check (definition-initial-context-name def-swift) => "Normal")
  (check (definition-initial-context-name def-vue) => "Normal")
  (check (definition-initial-context-name def-cmake) => "Normal Text")
  (check (definition-initial-context-name def-nix) => "Expression")
  (check (definition-initial-context-name def-bib) => "Normal")
  (check (definition-initial-context-name def-tex) => "Normal Text")
  (check (definition-initial-context-name def-hs) => "code")

  ;; 扩展名
  (check (definition-extensions def-scm) => '("*.scm" "*.ss" "*.scheme"))
  (check (definition-extensions def-json)
    =>
    '("*.json" "*.jsonl" "*.ndjson" "*.geojson")
  ) ;check
  (check-true
    (not (not (member "*.cpp" (definition-extensions def-cpp))))
  ) ;check-true
  (check-true
    (not (not (member "*.hpp" (definition-extensions def-cpp))))
  ) ;check-true
  (check-true
    (not (not (member "*.c" (definition-extensions def-c))))
  ) ;check-true
  (check-true
    (not (not (member "*.h" (definition-extensions def-c))))
  ) ;check-true
  (check-true
    (not (not (member "*.lua" (definition-extensions def-lua))))
  ) ;check-true
  (check-true
    (not (not (member "*.rockspec" (definition-extensions def-lua))))
  ) ;check-true
  (check-true
    (not (not (member "*.md" (definition-extensions def-md))))
  ) ;check-true
  (check-true
    (not (not (member "*.markdown" (definition-extensions def-md))))
  ) ;check-true
  (check-true
    (not (not (member "*.sh" (definition-extensions def-bash))))
  ) ;check-true
  (check-true
    (not (not (member "*.bash" (definition-extensions def-bash))))
  ) ;check-true
  (check-true
    (not (not (member "*.envrc" (definition-extensions def-bash))))
  ) ;check-true
  (check-true
    (not (not (member "PKGBUILD" (definition-extensions def-bash))))
  ) ;check-true

  ;; Scheme 上下文与样式
  (check-true (not (not (definition-find-context def-scm "Level0"))))
  (check-true (not (not (definition-find-context def-scm "Level1"))))
  (check-true (not (not (definition-find-context def-scm "comment"))))
  (check-true (not (not (definition-find-context def-scm "multiline-comment"))))
  (check-true (not (not (definition-find-context def-scm "string"))))
  (check-true (not (not (definition-find-context def-scm "char-lit"))))
  (check (definition-item-data-def-style def-scm "Keyword") => "Keyword")
  (check (definition-item-data-def-style def-scm "Comment") => "Comment")
  (check (definition-item-data-def-style def-scm "String") => "String")
  (check-true
    (> (length (context-def-rules (definition-find-context def-scm "Level0"))) 0)
  ) ;check-true

  ;; 每次调用返回新对象
  (check-true (not (eq? def-scm (load-syntax-definition "scheme"))))
) ;let

(check-report)
