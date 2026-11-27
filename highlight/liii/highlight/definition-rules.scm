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

(define-library (liii highlight definition-rules)
  (import (scheme base)
    (scheme char)
    (liii base)
    (liii list)
    (liii json)
    (liii hash-table)
    (liii string)
    (liii highlight rule)
  ) ;import
  (export %parse-kw-lists %parse-context-rules)
  (begin
    ;; 解析规则上的结构事件：字符串简写，或 {"type": ..., "structure": ...}。
    ;; 返回事件名称字符串；未声明时返回 #f。
    (define (parse-rule-event obj)
      (let ((raw (json-ref obj "event")))
        (cond ((string? raw)
               (if (string-null? raw)
                 (error 'structure-definition-error "Rule event must be a nonempty string" raw)
                 raw
               ) ;if
              ) ;
              ((json-object? raw)
               (let ((type (json-ref-string raw "type" ""))
                     (structure (json-ref-string raw "structure" ""))
                    ) ;
                 (if
                   (or (not (member type '("open" "close" "token"))) (string-null? structure))
                   (error 'structure-definition-error "Invalid rule event object" raw)
                   (string-append structure "-" type)
                 ) ;if
               ) ;let
              ) ;
              ((null? raw) #f)
              (else (error 'structure-definition-error "Rule event must be a string or object" raw)
              ) ;else
        ) ;cond
      ) ;let
    ) ;define

    ;; 附加结构事件：重建规则以携带 event 字段，不改变其余字段。
    (define (%rule-with-event rule event)
      (if (and rule event)
        (make-rule (rule-type rule)
          (rule-attribute rule)
          (rule-context-target rule)
          (rule-data rule)
          (rule-look-ahead? rule)
          (rule-first-non-space? rule)
          (rule-column rule)
          event
        ) ;make-rule
        rule
      ) ;if
    ) ;define

    ;; 按类型构造规则（不含事件）
    (define (%make-rule-by-type type-str obj attr ctx look-ahead first-non-space
              col kw-lists
            ) ;%make-rule-by-type
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
             (event (parse-rule-event obj))
             (rule (%make-rule-by-type type-str obj attr ctx look-ahead
                     first-non-space col kw-lists
                   ) ;%make-rule-by-type
             ) ;rule
            ) ;
        (%rule-with-event rule event)
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

    (define (%parse-kw-lists raw-lists)
      (if (json-object? raw-lists)
        (map (lambda (k) (parse-kw-list-item raw-lists k)) (json-keys raw-lists))
        '()
      ) ;if
    ) ;define

    (define (%parse-context-rules c-obj kw-lists)
      (let* ((rr (json-ref c-obj "rules"))
             (raw-rules (cond ((vector? rr) (vector->list rr)) ((list? rr) rr) (else '())))
            ) ;
        (filter (lambda (r) r)
          (map (lambda (ro) (parse-rule-json ro kw-lists)) raw-rules)
        ) ;filter
      ) ;let*
    ) ;define
  ) ;begin
) ;define-library
