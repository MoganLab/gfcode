;; parse-theme-json
;; 解析 KSyntaxHighlighting .theme JSON 对象。
;;
;; 语法
;; ----
;; (parse-theme-json theme-obj)
;;
;; 参数
;; ----
;; theme-obj : json-object
;; 主题 JSON 对象，含 metadata、text-styles、editor-colors。
;;
;; 返回值
;; ----
;; <theme>
;; 解析后的主题对象。

(import (scheme base)
  (liii check)
  (liii json)
  (liii path)
  (liii highlight theme)
) ;import

(check-set-mode! 'report-failed)

;; data 资源解析：gf test 目录模式会 chdir 到域根，兼容两种 cwd

(define (resource-file rel)
  (let ((local (string-append "highlight/resources/" rel))
        (alt (string-append "resources/" rel))
       ) ;
    (if (path-exists? local) local alt)
  ) ;let
) ;define

;; 从数据文件加载 Breeze Dark
(let* ((raw (string->json (path-read-text (resource-file "themes/breeze-dark.theme"))))
       (th (parse-theme-json raw))
      ) ;
  (check (theme-name th) => "Breeze Dark")
  (check-true (not (not (theme-text-style th "Keyword"))))
) ;let*

;; 内联最小 JSON
(let* ((raw (string->json (string-append "{\"metadata\": {\"name\": \"Mini\", \"revision\": 3},"
                            " \"text-styles\": {\"Keyword\": {\"text-color\": \"#ff0000\", \"bold\": true}},"
                            " \"editor-colors\": {\"BackgroundColor\": \"#232629\"}}"
                          ) ;string-append
            ) ;string->json
       ) ;raw
       (th (parse-theme-json raw))
       (kw (theme-text-style th "Keyword"))
      ) ;
  (check (theme-name th) => "Mini")
  (check (theme-revision th) => 3)
  (check-true (not (not kw)))
  (check (style-entry-text-color kw) => '(255 0 0))
  (check-true (style-entry-bold? kw))
  (check (theme-editor-color th "BackgroundColor") => '(35 38 41))
) ;let*

;; 缺 metadata 时用默认值
(let ((th (parse-theme-json (string->json "{}"))))
  (check (theme-name th) => "Unnamed")
  (check (theme-revision th) => 1)
  (check (theme-text-style th "Keyword") => #f)
) ;let

(check-report)
