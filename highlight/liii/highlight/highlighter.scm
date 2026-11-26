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

;; 高亮状态机、扫描循环与公开入口 highlight-line / highlight-text。
;; 上下文栈切换见 (liii highlight context-stack)，围栏代码块解析见
;; (liii highlight code-block)。

(define-library (liii highlight highlighter)
  (import (scheme base)
    (scheme char)
    (liii base)
    (liii list)
    (liii string)
    (liii hash-table)
    (liii highlight rule)
    (liii highlight rule-matcher)
    (liii highlight definition)
    (liii highlight theme)
    (liii highlight context-stack)
    (liii highlight code-block)
  ) ;import
  (export make-highlight-state highlight-state? highlight-state-stack
    initial-highlight-state highlight-line highlight-text
  ) ;export
  (begin

    ;; 高亮引擎跨行状态 record
    ;; stack: 上下文名称列表（栈顶在 car），例如 '("string" "Level0")
    (define*-record-type <highlight-state>
      (make-highlight-state (stack '("Level0")))
      highlight-state?
      (stack highlight-state-stack)
    ) ;define*-record-type

    (define (initial-highlight-state def)
      (make-highlight-state (list (definition-initial-context-name def)))
    ) ;define

    (define (first-non-space-index text)
      (let ((len (string-length text)))
        (let loop
          ((i 0))
          (cond ((= i len) len)
                ((not (char-whitespace? (string-ref text i))) i)
                (else (loop (+ i 1)))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%span-attr attr cur-def)
      (definition-item-data-def-style cur-def attr)
    ) ;define

    (define (handle-rule-match r res text offset stack spans cur-ctx cur-def loop)
      (let* ((new-offset (match-result-new-offset res))
             (len (- new-offset offset))
             (target (rule-context-target r))
            ) ;
        (cond
         ((eq? (rule-type r) 'include-rules)
          ;; IncludeRules：零宽匹配，不消耗文本，切换到子语言
          (let* ((lang-name (rule-data r)) (sub-def (%resolve-sub-definition lang-name)))
            (if (not sub-def)
              ;; 找不到子定义：当作不匹配，前进 1 字符避免死循环
              (loop (+ offset 1)
                stack
                (cons (list offset 1 (rule-attribute r) cur-def) spans)
              ) ;loop
              (let* ((init-ctx (definition-initial-context-name sub-def))
                     ;; 帧：(include sub-def inner-stack host-ctx host-def)
                     (frame (list 'include sub-def (list init-ctx) (context-def-name cur-ctx) cur-def)
                     ) ;frame
                    ) ;
                ;; 不前进 offset，不产生 span，仅压入 include 帧
                (loop offset (cons frame stack) spans)
              ) ;let*
            ) ;if
          ) ;let*
         ) ;
         (else
           (let ((next-stack (apply-context-switch stack target cur-def)))
             (if (rule-look-ahead? r)
               ;; lookAhead 规则：不前进 offset，只切换上下文
               (loop offset next-stack spans)
               ;; 正常规则：前进 offset 并记录 span
               (loop new-offset
                 next-stack
                 (cons (list offset len (rule-attribute r) cur-def) spans)
               ) ;loop
             ) ;if
           ) ;let
         ) ;else
        ) ;cond
      ) ;let*
    ) ;define

    (define (handle-no-rule-match cur-ctx offset stack spans cur-def loop)
      ;; 没有规则匹配：检查是否有 fallthrough-context
      (if (context-def-fallthrough-context cur-ctx)
        (let ((next-stack (apply-context-switch stack (context-def-fallthrough-context cur-ctx) cur-def)
              ) ;next-stack
             ) ;
          (loop offset next-stack spans)
        ) ;let
        ;; 消耗 1 个字符作为当前上下文的默认 attribute
        (loop (+ offset 1)
          stack
          (cons (list offset 1 (context-def-attribute cur-ctx) cur-def) spans)
        ) ;loop
      ) ;if
    ) ;define

    (define (scan-rules rules cur-ctx text offset text-len first-non-space stack
              spans cur-def loop
            ) ;scan-rules
      (if (null? rules)
        (handle-no-rule-match cur-ctx offset stack spans cur-def loop)
        (let* ((r (car rules)) (res (match-rule r text offset text-len first-non-space)))
          (if (match-result-matched? res)
            (handle-rule-match r res text offset stack spans cur-ctx cur-def loop)
            ;; 未匹配，试下一条
            (scan-rules (cdr rules)
              cur-ctx
              text
              offset
              text-len
              first-non-space
              stack
              spans
              cur-def
              loop
            ) ;scan-rules
          ) ;if
        ) ;let*
      ) ;if
    ) ;define

    (define (%highlight-code-content text stack lang-name sub-state fence-char fence-len)
      (let ((sub-def (and lang-name sub-state (%resolve-sub-definition lang-name))))
        (if sub-def
          (let-values (((sub-spans next-sub-state) (highlight-line text sub-state sub-def)))
            (let* ((new-frame (list 'fenced-code fence-char fence-len lang-name next-sub-state))
                   (new-stack (cons new-frame (cdr stack)))
                  ) ;
              (values sub-spans (make-highlight-state new-stack))
            ) ;let*
          ) ;let-values
          (let ((spans
                  (if (= (string-length text) 0) '() (list (list 0 (string-length text) "Code")))
                ) ;spans
               ) ;
            (values spans (make-highlight-state stack))
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    (define (highlight-line-in-code-block text stack def)
      (let* ((frame (car stack))
             (fence-char (cadr frame))
             (fence-len (caddr frame))
             (lang-name (cadddr frame))
             (sub-state (car (cddddr frame)))
            ) ;
        (if (%code-block-close-line? text fence-char fence-len)
          (let ((next-stack (if (null? (cdr stack))
                              (list (definition-initial-context-name def))
                              (cdr stack)
                            ) ;if
                ) ;next-stack
               ) ;
            (values (list (list 0 (string-length text) "Fenced Code"))
              (make-highlight-state next-stack)
            ) ;values
          ) ;let
          (%highlight-code-content text stack lang-name sub-state fence-char fence-len)
        ) ;if
      ) ;let*
    ) ;define

    ;; 合并扫描：在 include 帧内，先试宿主上下文规则（用于检测闭合标签），
    ;; 不中再试子定义当前上下文规则。这样宿主的 </style> 等规则可随时跳出嵌入。
    ;; frame: (include sub-def inner-stack host-ctx-name host-def)
    (define (scan-include text offset text-len first-non-space frame stack spans loop)
      (let* ((sub-def (cadr frame))
             (inner (caddr frame))
             (inner-top (if (null? inner) #f (car inner)))
             (sub-ctx (if inner-top (definition-find-context sub-def inner-top) #f))
             (host-ctx-name (cadddr frame))
             (host-def (car (cddddr frame)))
             (host-ctx (definition-find-context host-def host-ctx-name))
             (host-rules (if host-ctx (context-def-rules host-ctx) '()))
             (sub-rules (if sub-ctx (context-def-rules sub-ctx) '()))
            ) ;
        ;; 先试宿主规则
        (let try-host
          ((rs host-rules))
          (if (null? rs)
            ;; 宿主规则不匹配，试子规则
            (let try-sub
              ((rs2 sub-rules))
              (if (null? rs2)
                ;; 都不匹配：按子上下文默认 attribute 消耗 1 字符
                (loop (+ offset 1)
                  stack
                  (cons (list offset 1 (if sub-ctx (context-def-attribute sub-ctx) "Normal") sub-def)
                    spans
                  ) ;cons
                ) ;loop
                (let* ((r (car rs2)) (res (match-rule r text offset text-len first-non-space)))
                  (if (match-result-matched? res)
                    (handle-rule-match r res text offset stack spans sub-ctx sub-def loop)
                    (try-sub (cdr rs2))
                  ) ;if
                ) ;let*
              ) ;if
            ) ;let
            (let* ((r (car rs))
                   (res (if (eq? (rule-type r) 'include-rules)
                          #f
                          (match-rule r text offset text-len first-non-space)
                        ) ;if
                   ) ;res
                  ) ;
              (if (and res (match-result-matched? res))
                ;; 宿主规则命中：用宿主 def 处理切换（作用于 include 帧之外）
                (let* ((new-offset (match-result-new-offset res))
                       (len (- new-offset offset))
                       (target (rule-context-target r))
                       (next-stack (apply-context-switch-host stack target host-def))
                      ) ;
                  (if (rule-look-ahead? r)
                    (loop offset next-stack spans)
                    (loop new-offset
                      next-stack
                      (cons (list offset len (rule-attribute r) host-def) spans)
                    ) ;loop
                  ) ;if
                ) ;let*
                (try-host (cdr rs))
              ) ;if
            ) ;let*
          ) ;if
        ) ;let
      ) ;let*
    ) ;define

    (define (%scan-line text text-len first-non-space stack def)
      (let loop
        ((offset 0) (stack stack) (spans '()))
        (if (>= offset text-len)
          ;; 行尾：对栈顶上下文应用 line-end-context
          (let*-values (((cur-ctx cur-def) (%top-context stack def)))
            (let ((line-end-switch (if cur-ctx (context-def-line-end-context cur-ctx) '(stay))))
              (let ((final-stack (apply-context-switch stack line-end-switch def)))
                (values (reverse spans) (make-highlight-state final-stack))
              ) ;let
            ) ;let
          ) ;let*-values
          (let ((top (car stack)))
            (cond ((%include-frame? top)
                   (scan-include text offset text-len first-non-space top stack spans loop)
                  ) ;
                  (else
                    (let*-values (((cur-ctx cur-def) (%top-context stack def)))
                      (if (not cur-ctx)
                        (loop (+ offset 1) stack (cons (list offset 1 "Normal") spans))
                        (scan-rules (context-def-rules cur-ctx)
                          cur-ctx
                          text
                          offset
                          text-len
                          first-non-space
                          stack
                          spans
                          cur-def
                          loop
                        ) ;scan-rules
                      ) ;if
                    ) ;let*-values
                  ) ;else
            ) ;cond
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    (define (%highlight-line-normal text stack def)
      (let* ((text-len (string-length text)) (first-non-space (first-non-space-index text)))
        (if (= text-len 0)
          (let*-values (((cur-ctx cur-def) (%top-context stack def)))
            (let ((line-end-switch (if cur-ctx (context-def-line-end-context cur-ctx) '(stay))))
              (let ((next-stack (apply-context-switch stack line-end-switch def)))
                (values '() (make-highlight-state next-stack))
              ) ;let
            ) ;let
          ) ;let*-values
          (%scan-line text text-len first-non-space stack def)
        ) ;if
      ) ;let*
    ) ;define

    (define (%open-code-block text open-info stack)
      (let* ((fence-char (car open-info))
             (fence-len (cadr open-info))
             (raw-lang (caddr open-info))
             (norm-lang (%normalize-code-lang raw-lang))
             (sub-def (%resolve-sub-definition norm-lang))
             (sub-state (and sub-def (initial-highlight-state sub-def)))
             (frame (list 'fenced-code fence-char fence-len norm-lang sub-state))
             (next-stack (cons frame stack))
             (spans
               (if (= (string-length text) 0)
                 '()
                 (list (list 0 (string-length text) "Fenced Code"))
               ) ;if
             ) ;spans
            ) ;
        (values spans (make-highlight-state next-stack))
      ) ;let*
    ) ;define

    ;; 高亮单行
    ;; 输入：text (string), state (<highlight-state>), def (<definition>)
    ;; 返回：(values spans next-state)
    ;; spans 形式：'((offset length item-data-name) ...)
    (define (highlight-line text state def)
      (let ((stack (highlight-state-stack state)))
        (cond
         ((and (pair? stack) (fenced-code-frame? (car stack)))
          (highlight-line-in-code-block text stack def)
         ) ;
         ((and (string=? (definition-name def) "Markdown") (%parse-code-block-open text))
          (%open-code-block text (%parse-code-block-open text) stack)
         ) ;
         (else (%highlight-line-normal text stack def))
        ) ;cond
      ) ;let
    ) ;define

    (define (line-end-offset text i start)
      (if
        (and (> i start) (char=? (string-ref text (- i 1)) #\return))
        (- i 1)
        i
      ) ;if
    ) ;define

    ;; 拆分文本为行列表（保留换行前的内容，行尾不含 \r 或 \n）
    (define (split-text-lines text)
      (let ((len (string-length text)))
        (let loop
          ((i 0) (start 0) (lines '()))
          (cond
           ((= i len) (reverse (cons (substring text start len) lines)))
           ((char=? (string-ref text i) #\newline)
            (let ((end (line-end-offset text i start)))
              (loop (+ i 1) (+ i 1) (cons (substring text start end) lines))
            ) ;let
           ) ;
           (else (loop (+ i 1) start lines))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    ;; 高亮整段多行文本
    ;; 返回：'(((span ...) . "line-text") ...)
    (define (highlight-text text def)
      (let ((lines (split-text-lines text)) (init-state (initial-highlight-state def)))
        (let loop
          ((ls lines) (state init-state) (acc '()))
          (if (null? ls)
            (reverse acc)
            (let-values (((spans next-state) (highlight-line (car ls) state def)))
              (loop (cdr ls) next-state (cons (cons spans (car ls)) acc))
            ) ;let-values
          ) ;if
        ) ;let
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
