;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;; http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
;; WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
;; License for the specific language governing permissions and limitations
;; under the License.
;;

(define-library (liii highlight definition)
  (import (scheme base)
    (scheme char)
    (scheme file)
    (liii base)
    (liii list)
    (liii json)
    (liii hash-table)
    (liii path)
    (liii string)
    (liii sys)
    (liii highlight rule)
  ) ;import
  (export make-context-def context-def? context-def-name context-def-attribute
    context-def-line-end-context context-def-fallthrough-context
    context-def-rules make-definition definition? definition-name
    definition-extensions definition-contexts definition-item-datas
    definition-initial-context-name definition-find-context
    definition-item-data-def-style parse-definition-json load-syntax-definition
    load-definition-for-file
  ) ;export
  (begin

    ;; 单个上下文 record
    (define*-record-type <context-def>
      (make-context-def name
        (attribute "Normal")
        (line-end-context '(stay))
        (fallthrough-context #f)
        (rules '())
      ) ;make-context-def
      context-def?
      (name context-def-name)
      (attribute context-def-attribute)
      (line-end-context context-def-line-end-context)
      (fallthrough-context context-def-fallthrough-context)
      (rules context-def-rules)
    ) ;define*-record-type

    ;; 完整语法定义 record
    ;; contexts: alist (("ContextName" . <context-def>) ...)
    ;; item-datas: alist (("ItemName" . defStyleName) ...)
    (define*-record-type <definition>
      (make-definition name
        (extensions '())
        (initial-context-name "Level0")
        (contexts '())
        (item-datas '())
      ) ;make-definition
      definition?
      (name definition-name)
      (extensions definition-extensions)
      (initial-context-name definition-initial-context-name)
      (contexts definition-contexts)
      (item-datas definition-item-datas)
    ) ;define*-record-type

    (define (definition-find-context def name)
      (let ((p (assoc name (definition-contexts def))))
        (if p (cdr p) #f)
      ) ;let
    ) ;define

    (define (definition-item-data-def-style def item-name)
      (let ((p (assoc item-name (definition-item-datas def))))
        (if p (cdr p) item-name)
      ) ;let
    ) ;define

    ;; 从单个 JSON rule 对象解析为 <rule>
    (define (parse-rule-json obj kw-lists)
      (let* ((type-str (json-ref-string obj "type" "unknown"))
             (attr (json-ref-string obj "attribute" "Normal"))
             (ctx-str (json-ref-string obj "context" "#stay"))
             (ctx (parse-context-switch ctx-str))
             (look-ahead (json-ref-boolean obj "look-ahead" #f))
             (first-non-space (json-ref-boolean obj "first-non-space" #f))
             (col (json-ref-integer obj "column" -1))
            ) ;
        (cond
         ((string=? type-str "DetectChar")
          (let ((c-str (json-ref-string obj "char" "")))
            (make-rule 'detect-char
              attr
              ctx
              (if (string-null? c-str) #\nul (string-ref c-str 0))
              look-ahead
              first-non-space
              col
            ) ;make-rule
          ) ;let
         ) ;
         ((string=? type-str "Detect2Chars")
          (let ((c1 (json-ref-string obj "char" "")) (c2 (json-ref-string obj "char1" "")))
            (make-rule 'detect-2chars
              attr
              ctx
              (cons (if (string-null? c1) #\nul (string-ref c1 0))
                (if (string-null? c2) #\nul (string-ref c2 0))
              ) ;cons
              look-ahead
              first-non-space
              col
            ) ;make-rule
          ) ;let
         ) ;
         ((string=? type-str "AnyChar")
          (let ((s (json-ref-string obj "String" "")))
            (make-rule 'any-char attr ctx s look-ahead first-non-space col)
          ) ;let
         ) ;
         ((string=? type-str "StringDetect")
          (let ((s (json-ref-string obj "String" "")))
            (make-rule 'string-detect attr ctx s look-ahead first-non-space col)
          ) ;let
         ) ;
         ((string=? type-str "WordDetect")
          (let ((w (json-ref-string obj "String" ""))
                (delims (json-ref-string obj "delimiters" #f))
               ) ;
            (make-rule 'word-detect attr ctx (cons w delims) look-ahead first-non-space col)
          ) ;let
         ) ;
         ((string=? type-str "keyword")
          (let* ((list-name (json-ref-string obj "String" ""))
                 (delims (json-ref-string obj "delimiters" #f))
                 (kw-set
                   (let ((p (assoc list-name kw-lists)))
                     (if p (cdr p) '())
                   ) ;let
                 ) ;kw-set
                ) ;
            (make-rule 'keyword
              attr
              ctx
              (cons kw-set delims)
              look-ahead
              first-non-space
              col
            ) ;make-rule
          ) ;let*
         ) ;
         ((string=? type-str "Int")
          (let ((delims (json-ref-string obj "delimiters" #f)))
            (make-rule 'int attr ctx delims look-ahead first-non-space col)
          ) ;let
         ) ;
         ((string=? type-str "Float")
          (make-rule 'float attr ctx #f look-ahead first-non-space col)
         ) ;
         ((string=? type-str "Decimal")
          (make-rule 'decimal attr ctx #f look-ahead first-non-space col)
         ) ;
         ((or (string=? type-str "Hex") (string=? type-str "HlCHex"))
          (make-rule 'hex attr ctx #f look-ahead first-non-space col)
         ) ;
         ((string=? type-str "JsonEscapeChar")
          (make-rule 'json-escape-char attr ctx #f look-ahead first-non-space col)
         ) ;
         ((string=? type-str "JsonEscapeError")
          (make-rule 'json-escape-error attr ctx #f look-ahead first-non-space col)
         ) ;
         ((string=? type-str "RegExpr")
          (let ((pat (json-ref-string obj "String" "")))
            (cond ((string-contains? pat "\\.")
                   (make-rule 'float attr ctx #f look-ahead first-non-space col)
                  ) ;
                  ((string-contains? pat "0\\b|[1-9]")
                   (make-rule 'decimal attr ctx #f look-ahead first-non-space col)
                  ) ;
                  ((string-contains? pat "bfnrt")
                   (make-rule 'json-escape-char attr ctx #f look-ahead first-non-space col)
                  ) ;
                  ((string-contains? pat "u[0-9a-fA-F]+")
                   (make-rule 'json-escape-error attr ctx #f look-ahead first-non-space col)
                  ) ;
                  (else #f)
            ) ;cond
          ) ;let
         ) ;
         ((string=? type-str "DetectSpaces")
          (make-rule 'detect-spaces attr ctx #t look-ahead first-non-space col)
         ) ;
         ((string=? type-str "DetectIdentifier")
          (let ((delims (json-ref-string obj "delimiters" #f)))
            (make-rule 'detect-identifier attr ctx delims look-ahead first-non-space col)
          ) ;let
         ) ;
         ((string=? type-str "IncludeRules")
          (let* ((ctx-ref (json-ref-string obj "context-ref" ""))
                 (lang-name (if (string-starts? ctx-ref "##")
                              (substring ctx-ref 2)
                              (if (string-starts? ctx-ref "#") #f ctx-ref)
                            ) ;if
                 ) ;lang-name
                ) ;
            (if (not lang-name)
              #f
              (make-rule 'include-rules attr ctx lang-name look-ahead first-non-space col)
            ) ;if
          ) ;let*
         ) ;
         ((string=? type-str "CharsetRun")
          (let ((chars (json-ref-string obj "String" ""))
                (min-cnt (json-ref-integer obj "min" 1))
               ) ;
            (make-rule 'charset-run
              attr
              ctx
              (cons chars min-cnt)
              look-ahead
              first-non-space
              col
            ) ;make-rule
          ) ;let
         ) ;
         (else #f)
        ) ;cond
      ) ;let*
    ) ;define

    (define (parse-kw-list-item raw-lists k)
      (let* ((raw-arr (json-ref raw-lists k))
             (arr (cond ((vector? raw-arr) (vector->list raw-arr))
                        ((list? raw-arr) raw-arr)
                        (else '())
                  ) ;cond
             ) ;arr
             (ht (make-hash-table))
            ) ;
        (for-each (lambda (item) (hash-table-set! ht item #t)) arr)
        (cons k ht)
      ) ;let*
    ) ;define

    (define (parse-kw-lists raw-lists)
      (if (json-object? raw-lists)
        (map (lambda (k) (parse-kw-list-item raw-lists k)) (json-keys raw-lists))
        '()
      ) ;if
    ) ;define

    (define (parse-context-rules c-obj kw-lists)
      (let* ((rr (json-ref c-obj "rules"))
             (raw-rules (cond ((vector? rr) (vector->list rr)) ((list? rr) rr) (else '())))
            ) ;
        (filter (lambda (r) r)
          (map (lambda (ro) (parse-rule-json ro kw-lists)) raw-rules)
        ) ;filter
      ) ;let*
    ) ;define

    (define (parse-context-def-entry ctx-name raw-contexts kw-lists)
      (let* ((c-obj (json-ref raw-contexts ctx-name))
             (attr (json-ref-string c-obj "attribute" "Normal"))
             (line-end (parse-context-switch (json-ref-string c-obj "line-end-context" "#stay"))
             ) ;line-end
             (ft-str (json-ref-string c-obj "fallthrough-context" #f))
             (fallthrough (and ft-str (parse-context-switch ft-str)))
             (rules (parse-context-rules c-obj kw-lists))
            ) ;
        (cons ctx-name (make-context-def ctx-name attr line-end fallthrough rules))
      ) ;let*
    ) ;define

    ;; 从 JSON 对象解析整套语法定义
    (define (parse-definition-json root)
      (let* ((name (json-ref-string root "name" "Unnamed"))
             (raw-exts (json-ref root "extensions"))
             (exts (cond ((vector? raw-exts) (vector->list raw-exts))
                         ((list? raw-exts) raw-exts)
                         (else '())
                   ) ;cond
             ) ;exts
             (init-ctx (json-ref-string root "initial-context" "Level0"))
             (kw-lists (parse-kw-lists (json-ref root "lists")))
             ;; 解析 item-datas: {"Normal": "Normal", "Keyword": "Keyword"}
             (raw-items (json-ref root "item-datas"))
             (item-datas
               (if (json-object? raw-items)
                 (map (lambda (k) (cons k (json-ref-string raw-items k "Normal")))
                   (json-keys raw-items)
                 ) ;map
                 '()
               ) ;if
             ) ;item-datas
             ;; 解析 contexts
             (raw-contexts (json-ref root "contexts"))
             (contexts
               (if (json-object? raw-contexts)
                 (map (lambda (ctx-name) (parse-context-def-entry ctx-name raw-contexts kw-lists))
                   (json-keys raw-contexts)
                 ) ;map
                 '()
               ) ;if
             ) ;contexts
            ) ;
        (make-definition name exts init-ctx contexts item-datas)
      ) ;let*
    ) ;define

    ;; 资源目录定位：本文件位于 <domain>/liii/highlight/definition.scm，
    ;; 资源目录为 <domain>/resources/syntax。库加载时用 (liii sys) 的
    ;; library-file 捕获自身源文件的绝对路径并缓存，运行期不受 cwd
    ;; 变化影响；不直接依赖 goldfish 私有 glue。
    (define %syntax-resource-dir
      (let ((self (library-file)))
        (and self
          (path->string
            (path-join
              (path-parent (path-parent (path-parent (path self))))
              "resources"
              "syntax"
            ) ;path-join
          ) ;path->string
        ) ;and
      ) ;let
    ) ;define

    ;; 候选资源目录：优先用加载期缓存的绝对路径，
    ;; 未命中时退回 cwd 相对探测。
    (define (syntax-dir-candidates)
      (append (if %syntax-resource-dir (list %syntax-resource-dir) '())
        (list "highlight/resources/syntax" "../highlight/resources/syntax"
          "../../highlight/resources/syntax" "resources/syntax"
        ) ;list
      ) ;append
    ) ;define

    ;; 定位 highlight/resources/syntax/<name>.json 路径
    (define (find-syntax-file name)
      (let ((name-lower (string-downcase name)))
        (let loop
          ((dirs (syntax-dir-candidates)))
          (if (null? dirs)
            #f
            (let ((cand
                    (path->string (path-join (path (car dirs)) (string-append name-lower ".json")))
                  ) ;cand
                 ) ;
              (if (path-exists? cand) cand (loop (cdr dirs)))
            ) ;let
          ) ;if
        ) ;let
      ) ;let
    ) ;define
    ;; 列出 highlight/resources/syntax 目录下的所有语法定义文件
    (define (glob-syntax-dir)
      (let loop
        ((dirs (syntax-dir-candidates)))
        (if (null? dirs)
          '()
          (if (path-dir? (car dirs)) (path-glob (car dirs) "*.json") (loop (cdr dirs)))
        ) ;if
      ) ;let
    ) ;define

    ;; 根据语言标识（如 "c", "cpp", "json", "scheme"）从 JSON 文件加载语法定义
    (define (load-syntax-definition name)
      (let ((filepath (find-syntax-file name)))
        (if filepath
          (let* ((text (path-read-text filepath)) (obj (string->json text)))
            (parse-definition-json obj)
          ) ;let*
          (error "Syntax definition not found for language: " name)
        ) ;if
      ) ;let
    ) ;define

    (define (%match-extension? filename pat)
      (if (string-starts? pat "*.")
        (string-ends? filename (substring pat 1))
        (string=? filename pat)
      ) ;if
    ) ;define

    (define (%definition-matches-file? def filename)
      (let ((exts
              (cond ((vector? (definition-extensions def))
                     (vector->list (definition-extensions def))
                    ) ;
                    ((list? (definition-extensions def)) (definition-extensions def))
                    (else '())
              ) ;cond
            ) ;exts
           ) ;
        (any (lambda (p) (%match-extension? filename p)) exts)
      ) ;let
    ) ;define

    ;; 根据文件名（如 "main.c", "foo.cpp", "test.json"）自动查找并加载匹配的语法定义
    (define (load-definition-for-file filename)
      (let loop
        ((files (glob-syntax-dir)))
        (if (null? files)
          #f
          (let* ((p (path->string (car files)))
                 (text (path-read-text p))
                 (obj (string->json text))
                 (def (parse-definition-json obj))
                ) ;
            (if (%definition-matches-file? def filename) def (loop (cdr files)))
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
