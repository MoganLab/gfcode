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

;; 规则描述 record、上下文切换解析与规则匹配分发。
;; 各规则的 do-match 实现见 (liii highlight rule-matcher)。

(define-library (liii highlight rule)
  (import (scheme base)
    (scheme char)
    (liii base)
    (liii string)
    (liii hash-table)
    (liii highlight rule-matcher)
  ) ;import
  (export make-rule rule? rule-type rule-attribute rule-context-target rule-data
    rule-look-ahead? rule-first-non-space? rule-column rule-event
    parse-context-switch match-rule
  ) ;export
  (begin

    ;; 统一规则 record
    ;; type: 'detect-char | 'detect-2chars | 'any-char | 'string-detect
    ;;       | 'word-detect | 'keyword | 'int | 'float | 'decimal | 'hex
    ;;       | 'json-escape-char | 'json-escape-error | 'detect-spaces
    ;;       | 'detect-identifier | 'charset-run
    ;; attribute: 对应的 itemData 名称，例如 "Keyword"、"Normal"
    ;; context-target: 解析后的上下文切换指令，例如 '(stay), '(pop 1), '(push "XMLTag"), '(pop 1 "comment")
    ;; data: 规则专有负载
    ;;   detect-char: char
    ;;   detect-2chars: (cons char1 char2)
    ;;   any-char: string (字符集合)
    ;;   string-detect: string
    ;;   word-detect: (cons word delimiters-string)
    ;;   keyword: (cons keyword-set delimiters-string)  ; keyword-set 为 hash-table 或 list
    ;;   int: delimiters-string
    ;;   float: delimiters-string
    ;;   detect-spaces: #t
    ;;   detect-identifier: delimiters-string
    ;;   charset-run: (cons predicate-or-chars-string min-count)
    ;; event: 结构事件名称（string 或 #f），命中时通知结构流，不影响高亮。
    (define*-record-type <rule>
      (make-rule type
        attribute
        context-target
        (data #f)
        (look-ahead? #f)
        (first-non-space? #f)
        (column -1)
        (event #f)
      ) ;make-rule
      rule?
      (type rule-type)
      (attribute rule-attribute)
      (context-target rule-context-target)
      (data rule-data)
      (look-ahead? rule-look-ahead?)
      (first-non-space? rule-first-non-space?)
      (column rule-column)
      (event rule-event)
    ) ;define*-record-type

    (define (parse-pop-parens after pop-count loop)
      (let ((close-idx (string-index after #\))))
        (if close-idx
          (let* ((n-str (substring after 1 close-idx))
                 (n (or (string->number n-str) 1))
                 (rest (substring after (+ close-idx 1)))
                ) ;
            (if (string-starts? rest "!")
              (list 'pop (+ pop-count n) (substring rest 1))
              (loop rest (+ pop-count n))
            ) ;if
          ) ;let*
          (list 'pop (+ pop-count 1))
        ) ;if
      ) ;let
    ) ;define

    ;; 解析 Kate context 字符串为结构化指令
    ;; "#stay" -> '(stay)
    ;; "#pop" -> '(pop 1)
    ;; "#pop#pop" -> '(pop 2)
    ;; "#pop!Target" -> '(pop 1 "Target")
    ;; "#pop#pop!Target" -> '(pop 2 "Target")
    ;; "Target" -> '(push "Target")
    (define (parse-context-switch str)
      (cond
       ((or (not (string? str)) (string-null? str) (string=? str "#stay")) '(stay))
       (else
         (let loop
           ((s str) (pop-count 0))
           (cond
            ((string-starts? s "#pop")
             (let ((after (substring s 4)))
               (if (string-starts? after "(")
                 (parse-pop-parens after pop-count loop)
                 ;; 普通 #pop
                 (if (string-starts? after "!")
                   (list 'pop (+ pop-count 1) (substring after 1))
                   (loop after (+ pop-count 1))
                 ) ;if
               ) ;if
             ) ;let
            ) ;
            ((> pop-count 0)
             (if (string-null? s)
               (list 'pop pop-count)
               (if (string-starts? s "!")
                 (list 'pop pop-count (substring s 1))
                 (list 'pop pop-count s)
               ) ;if
             ) ;if
            ) ;
            (else (list 'push s))
           ) ;cond
         ) ;let
       ) ;else
      ) ;cond
    ) ;define

    ;; 对单条规则进行匹配，返回 match-result
    (define (match-rule r text offset text-len first-non-space)
      ;; 约束1: 指定列
      (if
        (and (>= (rule-column r) 0) (not (= (rule-column r) offset)))
        (%no-match offset)
        ;; 约束2: first-non-space 限制
        (if (and (rule-first-non-space? r) (> offset first-non-space))
          (%no-match offset)
          ;; 核心匹配分发
          (case (rule-type r)
                ((detect-char) (%match-detect-char (rule-data r) text offset text-len))
                ((detect-2chars) (%match-detect-2chars (rule-data r) text offset text-len))
                ((any-char) (%match-any-char (rule-data r) text offset text-len))
                ((string-detect) (%match-string-detect (rule-data r) text offset text-len))
                ((word-detect)
                 (%match-word-detect (car (rule-data r))
                   (cdr (rule-data r))
                   text
                   offset
                   text-len
                 ) ;%match-word-detect
                ) ;
                ((keyword)
                 (%match-keyword (car (rule-data r)) (cdr (rule-data r)) text offset text-len)
                ) ;
                ((int) (%match-int (rule-data r) text offset text-len))
                ((float) (%match-json-number #t text offset text-len))
                ((decimal) (%match-json-number #f text offset text-len))
                ((hex) (%match-hex text offset text-len))
                ((json-escape-char) (%match-json-escape-char text offset text-len))
                ((json-escape-error) (%match-json-escape-error text offset text-len))
                ((detect-spaces) (%match-detect-spaces text offset text-len))
                ((detect-identifier)
                 (%match-detect-identifier (rule-data r) text offset text-len)
                ) ;
                ((charset-run)
                 (%match-charset-run (car (rule-data r))
                   (cdr (rule-data r))
                   text
                   offset
                   text-len
                 ) ;%match-charset-run
                ) ;
                ((include-rules)
                 ;; 始终零宽匹配：IncludeRules 不消耗文本，
                 ;; 只触发上下文切换（切换到子语言）
                 (%matched offset)
                ) ;
                (else (%no-match offset))
          ) ;case
        ) ;if
      ) ;if
    ) ;define

  ) ;begin
) ;define-library
