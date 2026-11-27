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
    (liii highlight definition-rules)
    (liii highlight structure)
  ) ;import
  (export make-context-def context-def? context-def-name context-def-attribute
    context-def-line-end-context context-def-fallthrough-context
    context-def-rules make-definition definition? definition-name
    definition-extensions definition-contexts definition-item-datas
    definition-initial-context-name definition-find-context
    definition-item-data-def-style parse-definition-json load-syntax-definition
    load-definition-for-file definition-structures definition-line-blocks
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
    ;; structures: <structure-set>，语义切分声明；缺省为空，高亮行为不变。
    (define*-record-type <definition>
      (make-definition name
        (extensions '())
        (initial-context-name "Level0")
        (contexts '())
        (item-datas '())
        (structures (make-structure-set))
        (line-blocks '(("blank-separator" . #t) ("definitions" . #())))
      ) ;make-definition
      definition?
      (name definition-name)
      (extensions definition-extensions)
      (initial-context-name definition-initial-context-name)
      (contexts definition-contexts)
      (item-datas definition-item-datas)
      (structures definition-structures)
      (line-blocks definition-line-blocks)
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

    (define (parse-context-def-entry ctx-name raw-contexts kw-lists)
      (let* ((c-obj (json-ref raw-contexts ctx-name))
             (attr (json-ref-string c-obj "attribute" "Normal"))
             (line-end (parse-context-switch (json-ref-string c-obj "line-end-context" "#stay"))
             ) ;line-end
             (ft-str (json-ref-string c-obj "fallthrough-context" #f))
             (fallthrough (and ft-str (parse-context-switch ft-str)))
             (rules (%parse-context-rules c-obj kw-lists))
            ) ;
        (cons ctx-name (make-context-def ctx-name attr line-end fallthrough rules))
      ) ;let*
    ) ;define

    ;; 解析单个结构声明对象为 <structure-definition>。
    (define (parse-structure-json obj)
      (let* ((name (json-ref-string obj "name" ""))
             (role-str (json-ref-string obj "role" ""))
             (scope-str (json-ref-string obj "scope" ""))
             (role (if (string-null? role-str)
                     (error 'structure-definition-error "Structure role is required" name)
                     (string->symbol role-str)
                   ) ;if
             ) ;role
             (scope (if (string-null? scope-str)
                      (error 'structure-definition-error "Structure scope is required" name)
                      (string->symbol scope-str)
                    ) ;if
             ) ;scope
             (begin
               (json-ref-string obj "begin" "")
             ) ;begin
             (raw-end (json-ref obj "end"))
             (end (if (string? raw-end) raw-end #f))
             (raw-meta (json-ref obj "metadata"))
             (metadata
               (if (json-object? raw-meta)
                 (map (lambda (k) (cons (string->symbol k) (json-ref raw-meta k)))
                   (json-keys raw-meta)
                 ) ;map
                 '()
               ) ;if
             ) ;metadata
             (raw-children (json-ref obj "children"))
             (children (cond ((vector? raw-children) (vector->list raw-children))
                             ((list? raw-children) raw-children)
                             (else '())
                       ) ;cond
             ) ;children
             (include-begin (json-ref-boolean obj "include-begin" #t))
             (include-end (json-ref-boolean obj "include-end" #t))
             (raw-eof (json-ref obj "on-eof"))
             (on-eof (if (string? raw-eof)
                       (string->symbol raw-eof)
                       (if (eq? scope 'line) 'close 'emit-unclosed)
                     ) ;if
             ) ;on-eof
            ) ;
        (make-structure-definition name role scope begin end metadata children
          include-begin include-end on-eof
        ) ;make-structure-definition
      ) ;let*
    ) ;define

    ;; JSON 数组/列表 → 字符串列表；其他值→空列表。
    (define (%json-string-list raw)
      (cond ((vector? raw) (vector->list raw))
            ((list? raw) raw)
            (else '())
      ) ;cond
    ) ;define

    (define (parse-line-blocks-json raw)
      (let ((items (json-ref raw "line-blocks")))
        (cond ((null? items) '(("blank-separator" . #t) ("definitions" . #())))
              ((json-object? items) items)
              (else (error 'structure-definition-error "line-blocks must be an object" items))
        ) ;cond
      ) ;let
    ) ;define

    ;; 解析顶层 segments 对象；返回 (structure-set . engine-events)。
    (define (parse-segments-json root)
      (let ((raw (json-ref root "segments")))
        (cond ((null? raw) (cons (make-structure-set) '()))
              ((json-object? raw)
               (let* ((version (json-ref-integer raw "version" 1))
                      (default-str (json-ref-string raw "default" "text"))
                      (root-scope-str (json-ref-string raw "root-scope" "top-level"))
                      (raw-structures (json-ref raw "structures"))
                      (items (cond ((vector? raw-structures) (vector->list raw-structures))
                                   ((list? raw-structures) raw-structures)
                                   (else '())
                             ) ;cond
                      ) ;items
                     ) ;
                 (cons (make-structure-set version
                         (string->symbol default-str)
                         (string->symbol root-scope-str)
                         (map parse-structure-json items)
                       ) ;make-structure-set
                   (%json-string-list (json-ref raw "engine-events"))
                 ) ;cons
               ) ;let*
              ) ;
              (else (error 'structure-definition-error "segments must be an object" raw))
        ) ;cond
      ) ;let
    ) ;define

    ;; 汇总所有规则声明的事件名（去重）。
    (define (%collect-rule-events contexts)
      (let loop
        ((rules
           (apply append (map (lambda (c) (context-def-rules (cdr c))) contexts))
         ) ;rules
         (acc '())
        ) ;
        (cond ((null? rules) acc)
              ((and (rule-event (car rules)) (not (member (rule-event (car rules)) acc)))
               (loop (cdr rules) (cons (rule-event (car rules)) acc))
              ) ;
              (else (loop (cdr rules) acc))
        ) ;cond
      ) ;let
    ) ;define

    ;; 结构引用的 begin/end 事件列表。
    (define (%structure-referenced-events d)
      (if (structure-definition-end d)
        (list (structure-definition-begin d) (structure-definition-end d))
        (list (structure-definition-begin d))
      ) ;if
    ) ;define

    (define (%require-member item known message)
      (if (not (member item known))
        (error 'structure-definition-error message item)
        #t
      ) ;if
    ) ;define

    ;; 交叉校验：结构引用的 begin/end 事件必须由规则或引擎声明；
    ;; 声明的事件必须被某个结构使用；children 引用存在的结构名。
    ;; engine-events：引擎特殊结构（如 fenced code）发出的事件名列表。
    (define (validate-structure-references contexts structures engine-events)
      (let* ((rule-events (append (%collect-rule-events contexts) engine-events))
             (defs (structure-set-structures structures))
             (names (map structure-definition-name defs))
             (referenced (apply append (map %structure-referenced-events defs)))
            ) ;
        (for-each (lambda (ev)
                    (%require-member ev rule-events "Structure references an undeclared event")
                  ) ;lambda
          referenced
        ) ;for-each
        (for-each (lambda (ev)
                    (%require-member ev referenced "Rule event is not used by any structure")
                  ) ;lambda
          rule-events
        ) ;for-each
        (for-each
          (lambda (d)
            (for-each (lambda (child) (%require-member child names "Unknown child structure"))
              (structure-definition-children d)
            ) ;for-each
          ) ;lambda
          defs
        ) ;for-each
        #t
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
             (kw-lists (%parse-kw-lists (json-ref root "lists")))
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
             (segments (parse-segments-json root))
             (structures (car segments))
            ) ;
        (validate-structure-references contexts structures (cdr segments))
        (make-definition name
          exts
          init-ctx
          contexts
          item-datas
          structures
          (parse-line-blocks-json (json-ref root "segments"))
        ) ;make-definition
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
