;; load-definition-for-file
;; 根据文件名自动查找并加载匹配的语法定义。
;;
;; 语法
;; ----
;; (load-definition-for-file filename)
;;
;; 参数
;; ----
;; filename : string
;; 文件名或路径，如 "main.c"、"foo.cpp"、"data.json"、"test.scm"。
;;
;; 返回值
;; ----
;; <definition> 或 #f
;; 匹配到的语法定义对象，若无匹配定义返回 #f。

(import (scheme base) (liii check) (liii highlight definition))

(check-set-mode! 'report-failed)

(check (definition-name (load-definition-for-file "altsvc.c")) => "C")
(check (definition-name (load-definition-for-file "convert.hpp")) => "C++")
(check (definition-name (load-definition-for-file "main.cpp")) => "C++")
(check (definition-name (load-definition-for-file "package.json")) => "JSON")
(check (definition-name (load-definition-for-file "test.scm")) => "Scheme")
(check (definition-name (load-definition-for-file "xmake.lua")) => "Lua")
(check (definition-name (load-definition-for-file "deploy.sh")) => "Bash")
(check (definition-name (load-definition-for-file ".bashrc")) => "Bash")
(check (definition-name (load-definition-for-file "PKGBUILD")) => "Bash")
(check (definition-name (load-definition-for-file "main.js")) => "JavaScript")
(check (definition-name (load-definition-for-file "index.mjs")) => "JavaScript")
(check (definition-name (load-definition-for-file "app.cjs")) => "JavaScript")
(check (definition-name (load-definition-for-file "main.py")) => "Python")
(check (definition-name (load-definition-for-file "setup.pyw")) => "Python")
(check (definition-name (load-definition-for-file "SConstruct")) => "Python")
(check (definition-name (load-definition-for-file "main.rs")) => "Rust")
(check (definition-name (load-definition-for-file "app.ts")) => "TypeScript")
(check (definition-name (load-definition-for-file "index.mts")) => "TypeScript")
(check (definition-name (load-definition-for-file "config.yaml")) => "YAML")
(check (definition-name (load-definition-for-file "config.yml")) => "YAML")
(check (definition-name (load-definition-for-file ".clang-format")) => "YAML")
(check (definition-name (load-definition-for-file "Cargo.toml")) => "TOML")
(check (definition-name (load-definition-for-file "Cargo.lock")) => "TOML")
(check (definition-name (load-definition-for-file "app.ini")) => "TOML")
(check (definition-name (load-definition-for-file "query.sql")) => "SQL")
(check (definition-name (load-definition-for-file "schema.ddl")) => "SQL")
(check (definition-name (load-definition-for-file "main.rb")) => "Ruby")
(check (definition-name (load-definition-for-file "Gemfile")) => "Ruby")
(check (definition-name (load-definition-for-file "Rakefile")) => "Ruby")
(check (definition-name (load-definition-for-file "index.php")) => "PHP")
(check (definition-name (load-definition-for-file "page.phtml")) => "PHP")
(check (definition-name (load-definition-for-file "Main.kt")) => "Kotlin")
(check (definition-name (load-definition-for-file "build.gradle.kts"))
  =>
  "Kotlin"
) ;check
(check (definition-name (load-definition-for-file "Main.swift")) => "Swift")
(check (definition-name (load-definition-for-file "App.vue")) => "Vue")
(check (definition-name (load-definition-for-file "CMakeLists.txt")) => "CMake")
(check (definition-name (load-definition-for-file "toolchain.cmake"))
  =>
  "CMake"
) ;check
(check (definition-name (load-definition-for-file "config.cmake.in"))
  =>
  "CMake"
) ;check
(check (definition-name (load-definition-for-file "flake.nix")) => "Nix")
(check (definition-name (load-definition-for-file "configuration.nix"))
  =>
  "Nix"
) ;check
(check (definition-name (load-definition-for-file "refs.bib")) => "BibTeX")
(check (definition-name (load-definition-for-file "paper.tex")) => "LaTeX")
(check (definition-name (load-definition-for-file "thesis.ltx")) => "LaTeX")
(check (definition-name (load-definition-for-file "style.sty")) => "LaTeX")
(check (definition-name (load-definition-for-file "article.cls")) => "LaTeX")
(check (definition-name (load-definition-for-file "diagram.tikz")) => "LaTeX")
(check (definition-name (load-definition-for-file "Main.hs")) => "Haskell")
(check (definition-name (load-definition-for-file "Setup.lhs")) => "Haskell")
(check (load-definition-for-file "unknown.xyz123") => #f)

(check-report)
