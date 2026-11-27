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
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.
;;

(define-library (liii highlight structure)
  (import (scheme base) (liii base))
  (export make-structure-definition structure-definition?
    structure-definition-name structure-definition-role
    structure-definition-scope structure-definition-begin
    structure-definition-end structure-definition-metadata
    structure-definition-children structure-definition-include-begin?
    structure-definition-include-end? structure-definition-on-eof
    make-structure-set structure-set? structure-set-version
    structure-set-default structure-set-root-scope structure-set-structures
  ) ;export
  (begin

    (define (%nonempty-string? value)
      (and (string? value) (> (string-length value) 0))
    ) ;define

    (define (%string-list? values)
      (and (list? values)
        (let loop
          ((rest values))
          (cond ((null? rest) #t)
                ((and (pair? rest) (string? (car rest))) (loop (cdr rest)))
                (else #f)
          ) ;cond
        ) ;let
      ) ;and
    ) ;define

    (define (%valid-on-eof? scope on-eof)
      (if (eq? scope 'line)
        (eq? on-eof 'close)
        (and (memq on-eof '(emit-unclosed error-and-emit)) #t)
      ) ;if
    ) ;define

    (define (%validate-structure-definition name role scope begin end metadata
              children include-begin? include-end? on-eof
            ) ;%validate-structure-definition
      (cond ((not (%nonempty-string? name))
             (error 'structure-definition-error
               "Structure name must be a nonempty string"
               name
             ) ;error
            ) ;
            ((not (symbol? role))
             (error 'structure-definition-error "Structure role must be a symbol" role)
            ) ;
            ((not (memq scope '(line delimited nested)))
             (error 'structure-definition-error "Unknown structure scope" scope)
            ) ;
            ((not (%nonempty-string? begin))
             (error 'structure-definition-error
               "Structure begin event must be a nonempty string"
               begin
             ) ;error
            ) ;
            ((and (eq? scope 'line) end)
             (error 'structure-definition-error
               "A line structure closes at a real line end"
               end
             ) ;error
            ) ;
            ((and (not (eq? scope 'line)) (not (%nonempty-string? end)))
             (error 'structure-definition-error
               "Delimited and nested structures require an end event"
               end
             ) ;error
            ) ;
            ((not (list? metadata))
             (error 'structure-definition-error
               "Structure metadata must be an alist"
               metadata
             ) ;error
            ) ;
            ((not (%string-list? children))
             (error 'structure-definition-error
               "Structure children must be a list of names"
               children
             ) ;error
            ) ;
            ((and (not (eq? scope 'nested)) (pair? children))
             (error 'structure-definition-error
               "Only nested structures can declare children"
               children
             ) ;error
            ) ;
            ((not (boolean? include-begin?))
             (error 'structure-definition-error
               "include-begin must be boolean"
               include-begin?
             ) ;error
            ) ;
            ((not (boolean? include-end?))
             (error 'structure-definition-error "include-end must be boolean" include-end?)
            ) ;
            ((not (%valid-on-eof? scope on-eof))
             (error 'structure-definition-error
               "Invalid EOF policy for structure scope"
               scope
               on-eof
             ) ;error
            ) ;
            (else #t)
      ) ;cond
    ) ;define

    ;; scope:
    ;;   line      当前真实行尾正常闭合；on-eof 固定为 close。
    ;;   delimited 由独立的开始/结束事件闭合，不声明结构子节点。
    ;;   nested    可递归嵌套，children 是允许的结构名称列表。
    ;; EOF:
    ;;   close           按正常闭合处理，仅用于 line。
    ;;   emit-unclosed   交付原文并标记 closed? = #f。
    ;;   error-and-emit  先报告 unexpected-eof，再按未闭合结构交付。
    (define*-record-type <structure-definition>
      (make-structure-definition name
        role
        scope
        begin
        (end #f)
        (metadata '())
        (children '())
        (include-begin? #t)
        (include-end? #t)
        (on-eof (if (eq? scope 'line) 'close 'emit-unclosed))
      ) ;make-structure-definition
      structure-definition?
      (name structure-definition-name)
      (role structure-definition-role)
      (scope structure-definition-scope)
      (begin
        structure-definition-begin
      ) ;begin
      (end structure-definition-end)
      (metadata structure-definition-metadata)
      (children structure-definition-children)
      (include-begin? structure-definition-include-begin?)
      (include-end? structure-definition-include-end?)
      (on-eof structure-definition-on-eof)
    ) ;define*-record-type

    ;; define*-record-type 不执行字段校验，包装构造器保持公开 API 不变。
    (define %make-structure-definition make-structure-definition)

    (set! make-structure-definition
      (lambda (name role scope begin . options)
        (let ((definition (apply %make-structure-definition name role scope begin options)))
          (%validate-structure-definition (structure-definition-name definition)
            (structure-definition-role definition)
            (structure-definition-scope definition)
            (structure-definition-begin definition)
            (structure-definition-end definition)
            (structure-definition-metadata definition)
            (structure-definition-children definition)
            (structure-definition-include-begin? definition)
            (structure-definition-include-end? definition)
            (structure-definition-on-eof definition)
          ) ;%validate-structure-definition
          definition
        ) ;let
      ) ;lambda
    ) ;set!

    (define (%unique-structure-names? structures)
      (let loop
        ((rest structures) (names '()))
        (cond ((null? rest) #t)
              ((member (structure-definition-name (car rest)) names) #f)
              (else
                (loop (cdr rest) (cons (structure-definition-name (car rest)) names))
              ) ;else
        ) ;cond
      ) ;let
    ) ;define

    (define (%validate-structure-set version default root-scope structures)
      (cond ((not (eqv? version 1))
             (error 'structure-definition-error
               "Unsupported structure schema version"
               version
             ) ;error
            ) ;
            ((not (eq? default 'text))
             (error 'structure-definition-error
               "Only text is supported as the default structure"
               default
             ) ;error
            ) ;
            ((not (symbol? root-scope))
             (error 'structure-definition-error "Root scope must be a symbol" root-scope)
            ) ;
            ((not (list? structures))
             (error 'structure-definition-error "Structures must be a list" structures)
            ) ;
            ((not
               (let loop
                 ((rest structures))
                 (cond ((null? rest) #t)
                       ((structure-definition? (car rest)) (loop (cdr rest)))
                       (else #f)
                 ) ;cond
               ) ;let
             ) ;not
             (error 'structure-definition-error "Invalid structure definition" structures)
            ) ;
            ((not (%unique-structure-names? structures))
             (error 'structure-definition-error "Duplicate structure name" structures)
            ) ;
            (else #t)
      ) ;cond
    ) ;define

    (define*-record-type <structure-set>
      (make-structure-set (version 1)
        (default 'text)
        (root-scope 'top-level)
        (structures '())
      ) ;make-structure-set
      structure-set?
      (version structure-set-version)
      (default structure-set-default)
      (root-scope structure-set-root-scope)
      (structures structure-set-structures)
    ) ;define*-record-type

    (define %make-structure-set make-structure-set)

    (set! make-structure-set
      (lambda options
        (let ((structure-set (apply %make-structure-set options)))
          (%validate-structure-set (structure-set-version structure-set)
            (structure-set-default structure-set)
            (structure-set-root-scope structure-set)
            (structure-set-structures structure-set)
          ) ;%validate-structure-set
          structure-set
        ) ;let
      ) ;lambda
    ) ;set!

  ) ;begin
) ;define-library
