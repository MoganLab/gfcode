;; parse-definition-json
;; 从 JSON 对象解析整套语法定义。
;;
;; 语法
;; ----
;; (parse-definition-json root)
;;
;; 参数
;; ----
;; root : json-object
;; 语法定义 JSON 对象。
;;
;; 返回值
;; ----
;; <definition>
;; 解析后的语法定义对象。

(import (scheme base)
  (liii check)
  (liii json)
  (liii path)
  (liii highlight definition)
) ;import
(check-set-mode! 'report-failed)

;; 资源解析：gf test 目录模式会 chdir 到域根，兼容域内与仓库根两种 cwd

(define (resource-file rel)
  (let ((local (string-append "highlight/resources/" rel))
        (alt (string-append "resources/" rel))
       ) ;
    (if (path-exists? local) local alt)
  ) ;let
) ;define

;; 最小对象：使用默认值
(let* ((raw (string->json "{\"name\": \"Tiny\"}")) (def (parse-definition-json raw)))
  (check (definition-name def) => "Tiny")
  (check (definition-initial-context-name def) => "Level0")
  (check (definition-contexts def) => '())
  (check (definition-item-datas def) => '())
) ;let*

;; 完整结构：contexts、rules、item-datas
(let* ((raw (string->json (string-append "{\"name\": \"Demo\","
                            " \"extensions\": [\"*.demo\"],"
                            " \"initial-context\": \"Base\","
                            " \"item-datas\": {\"Keyword\": \"Keyword\"},"
                            " \"contexts\": {\"Base\": {\"attribute\": \"Normal\","
                            "   \"rules\": [{\"type\": \"DetectChar\", \"char\": \";\","
                            "     \"attribute\": \"Comment\", \"context\": \"#stay\"}]}}"
                            "}"
                          ) ;string-append
            ) ;string->json
       ) ;raw
       (def (parse-definition-json raw))
       (ctx (definition-find-context def "Base"))
      ) ;
  (check (definition-name def) => "Demo")
  (check (definition-extensions def) => '("*.demo"))
  (check (definition-initial-context-name def) => "Base")
  (check-true (not (not ctx)))
  (check (context-def-attribute ctx) => "Normal")
  (check (= (length (context-def-rules ctx)) 1) => #t)
  (check (definition-item-data-def-style def "Keyword") => "Keyword")
) ;let*

;; 从数据文件加载真实 Scheme 定义
(let* ((raw-def (string->json (path-read-text (resource-file "syntax/scheme.json"))))
       (def (parse-definition-json raw-def))
      ) ;
  (check (definition-name def) => "Scheme")
  (check (definition-initial-context-name def) => "Level0")
) ;let*

;; 从数据文件加载真实 JSON 定义
(let* ((raw-def (string->json (path-read-text (resource-file "syntax/json.json"))))
       (def (parse-definition-json raw-def))
      ) ;
  (check (definition-name def) => "JSON")
  (check (definition-initial-context-name def) => "Normal")
  (check-true (not (not (definition-find-context def "Normal"))))
  (check-true (not (not (definition-find-context def "Pair"))))
) ;let*

;; 从数据文件加载真实 C++ 定义
(let* ((raw-def (string->json (path-read-text (resource-file "syntax/cpp.json"))))
       (def (parse-definition-json raw-def))
      ) ;
  (check (definition-name def) => "C++")
  (check (definition-initial-context-name def) => "Normal")
  (check-true (not (not (definition-find-context def "Normal"))))
  (check-true (not (not (definition-find-context def "preprocessor"))))
) ;let*

;; 从数据文件加载真实 C 定义
(let* ((raw-def (string->json (path-read-text (resource-file "syntax/c.json"))))
       (def (parse-definition-json raw-def))
      ) ;
  (check (definition-name def) => "C")
  (check (definition-initial-context-name def) => "Normal")
  (check-true (not (not (definition-find-context def "Normal"))))
  (check-true (not (not (definition-find-context def "preprocessor"))))
) ;let*

;; 从数据文件加载真实 Lua 定义
(let* ((raw-def (string->json (path-read-text (resource-file "syntax/lua.json"))))
       (def (parse-definition-json raw-def))
      ) ;
  (check (definition-name def) => "Lua")
  (check (definition-initial-context-name def) => "Normal")
  (check-true (not (not (definition-find-context def "Normal"))))
  (check-true (not (not (definition-find-context def "comment-line"))))
  (check-true (not (not (definition-find-context def "comment-block"))))
  (check-true (not (not (definition-find-context def "raw-string"))))
) ;let*

;; 从数据文件加载真实 Bash 定义
(let* ((raw-def (string->json (path-read-text (resource-file "syntax/bash.json"))))
       (def (parse-definition-json raw-def))
      ) ;
  (check (definition-name def) => "Bash")
  (check (definition-initial-context-name def) => "Normal")
  (check-true (not (not (definition-find-context def "Normal"))))
  (check-true (not (not (definition-find-context def "comment"))))
  (check-true (not (not (definition-find-context def "string-double"))))
  (check-true (not (not (definition-find-context def "var-brace"))))
) ;let*

(check-report)
