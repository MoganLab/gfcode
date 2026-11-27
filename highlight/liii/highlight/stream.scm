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

(define-library (liii highlight stream)
  (import (scheme base)
    (liii base)
    (liii string)
    (liii highlight rule)
    (liii highlight definition)
    (liii highlight structure)
    (liii highlight highlighter)
  ) ;import
  (export make-structure-stream structure-stream? structure-stream-feed!
    structure-stream-finish! structure-stream-text
  ) ;export
  (begin

    ;; 结构事件流：按 syntax JSON 声明的语义结构产生事件。
    ;;
    ;; 事件形式（回调参数，list）：
    ;;   (open name role metadata)         结构打开
    ;;   (content text spans)              已确定的原文片段 + 局部高亮 spans
    ;;   (close name role closed? text)    结构关闭；text 为完整原文
    ;;   (error reason detail)             unexpected-close /
    ;;                                     mismatched-delimiter / unexpected-eof
    ;;
    ;; 输入块只是传输单位：feed! 末尾不构成结构边界；
    ;; 真实行尾（\n）触发 line 结构闭合，finish! 触发 EOF 收尾。
    ;; content 事件只交付已确定部分：可能成为开始标记前缀的行尾字符被暂存。

    (define*-record-type <structure-stream>
      (make-structure-stream def
        emit-event
        (state (initial-highlight-state def))
        (pending "")
        (open-stack '())
        (line-open '())
        (last-content #f)
        (content-box (list ""))
        (finished? #f)
        (line-sink #f)
      ) ;make-structure-stream
      structure-stream?
      (def structure-stream-def)
      (emit-event structure-stream-emit)
      (state structure-stream-state set-structure-stream-state!)
      (pending structure-stream-pending set-structure-stream-pending!)
      (open-stack structure-stream-open-stack set-structure-stream-open-stack!)
      (line-open structure-stream-line-open set-structure-stream-line-open!)
      (last-content structure-stream-last-content set-structure-stream-last-content!)
      (content-box structure-stream-content-box)
      (line-sink stream-line-sink)
      (finished? structure-stream-finished? set-structure-stream-finished?!)
    ) ;define*-record-type

    ;; 打开中的结构帧：(definition accumulated-text)
    ;; line-open 记录本行内打开的 line 结构（逆序），用于真实行尾闭合。

    (define (%emit stream event)
     ((structure-stream-emit stream) event)
    ) ;define

    ;; 原文账本：只记录顶层交付（content 与最外层 close），
    ;; 嵌套 close 的文本已并入父结构，不重复计数。
    (define (%record-text stream text)
      (set-car! (structure-stream-content-box stream)
        (string-append (car (structure-stream-content-box stream)) text)
      ) ;set-car!
    ) ;define

    ;; 已交付原文的总拼接，应严格等于已消费输入。
    (define (structure-stream-text stream)
      (car (structure-stream-content-box stream))
    ) ;define

    (define (%find-structure-by-event structure-set event-name begin?)
      (let loop
        ((defs (structure-set-structures structure-set)))
        (cond ((null? defs) #f)
              ((string=?
                 (if begin?
                   (structure-definition-begin (car defs))
                   (or (structure-definition-end (car defs)) "")
                 ) ;if
                 event-name
               ) ;string=?
               (car defs)
              ) ;
              (else (loop (cdr defs)))
        ) ;cond
      ) ;let
    ) ;define

    ;; 合并静态与动态元数据：动态键覆盖同名静态键。
    (define (%merge-metadata static dynamic)
      (let loop
        ((rest static) (acc dynamic))
        (cond ((null? rest) acc)
              ((assq (caar rest) acc) (loop (cdr rest) acc))
              (else (loop (cdr rest) (cons (car rest) acc)))
        ) ;cond
      ) ;let
    ) ;define

    ;; 打开一个结构；line 结构登记到 line-open。
    ;; meta 为引擎提供的动态元数据（如 fenced code 的 language），
    ;; 覆盖静态声明中的同名键。
    (define (%open-structure stream sdef piece meta)
      (set-structure-stream-last-content! stream #f)
      (%emit stream
        (list 'open
          (structure-definition-name sdef)
          (structure-definition-role sdef)
          (%merge-metadata (structure-definition-metadata sdef) meta)
        ) ;list
      ) ;%emit
      (set-structure-stream-open-stack! stream
        (cons (list sdef piece) (structure-stream-open-stack stream))
      ) ;set-structure-stream-open-stack!
      (if (eq? (structure-definition-scope sdef) 'line)
        (set-structure-stream-line-open! stream
          (cons (structure-definition-name sdef) (structure-stream-line-open stream))
        ) ;set-structure-stream-line-open!
      ) ;if
    ) ;define

    ;; 弹出栈顶结构并交付 close 事件。
    (define (%close-top stream closed? extra-text)
      (set-structure-stream-last-content! stream #f)
      (let* ((frame (car (structure-stream-open-stack stream)))
             (sdef (car frame))
             (text (string-append (cadr frame) extra-text))
            ) ;
        (set-structure-stream-open-stack! stream
          (cdr (structure-stream-open-stack stream))
        ) ;set-structure-stream-open-stack!
        ;; 子结构完整原文并入父结构累积文本，保证 close 携带完整片段；
        ;; 最外层 close 记入原文账本。
        (if (not (null? (structure-stream-open-stack stream)))
          (let ((parent (car (structure-stream-open-stack stream))))
            (set-structure-stream-open-stack! stream
              (cons (list (car parent) (string-append (cadr parent) text))
                (cdr (structure-stream-open-stack stream))
              ) ;cons
            ) ;set-structure-stream-open-stack!
          ) ;let
          (%record-text stream text)
        ) ;if
        (%emit stream
          (list 'close
            (structure-definition-name sdef)
            (structure-definition-role sdef)
            closed?
            text
          ) ;list
        ) ;%emit
        text
      ) ;let*
    ) ;define

    ;; 关闭事件处理：匹配栈顶 end 事件则正常闭合；
    ;; 空栈报 unexpected-close；不匹配报 mismatched-delimiter，不弹栈。
    (define (%handle-close-event stream event-name piece)
      (let ((stack (structure-stream-open-stack stream)))
        (cond ((null? stack)
               (set-structure-stream-last-content! stream #f)
               (%emit stream (list 'error 'unexpected-close event-name))
               ;; 多余关闭标记原文保留为顶层 content。
               (%emit-content stream piece '() 0)
              ) ;
              ((string=? (or (structure-definition-end (caar stack)) "") event-name)
               (%close-top stream #t piece)
              ) ;
              (else (set-structure-stream-last-content! stream #f)
                (%emit stream
                  (list 'error
                    'mismatched-delimiter
                    (list event-name (structure-definition-name (caar stack)))
                  ) ;list
                ) ;%emit
                ;; 不匹配的关闭标记原文并入当前结构，不丢失。
                (%emit-content stream piece '() 0)
              ) ;else
        ) ;cond
      ) ;let
    ) ;define

    ;; 把事件应用到文本片段；返回该片段消费后的剩余归属文本。
    ;; piece 为事件匹配串（开/闭标记），事件之间的间隙由调用方交付 content。
    (define (%apply-event stream event-name piece meta)
      (let* ((sset (definition-structures (structure-stream-def stream)))
             (begin-def (%find-structure-by-event sset event-name #t))
            ) ;
        (cond (begin-def (%open-structure stream begin-def piece meta))
              ((%find-structure-by-event sset event-name #f)
               (%handle-close-event stream event-name piece)
              ) ;
              ;; 未声明的事件（如 fenced code 内子语言的规则事件）：
              ;; 原文并入当前结构，不丢失。
              (else (%emit-content stream piece '() 0))
        ) ;cond
      ) ;let*
    ) ;define

    ;; 处理一行（不含换行符）：按事件切分，间隙交付 content；
    ;; 事件匹配串并入当前结构或作为顶层 content。
    (define (%process-line stream line)
      (let*-values (((spans next-state events)
                     (highlight-line-events line
                       (structure-stream-state stream)
                       (structure-stream-def stream)
                     ) ;highlight-line-events
                    ) ;
                   ) ;
        (set-structure-stream-state! stream next-state)
        (let loop
          ((evs events) (pos 0))
          (if (null? evs)
            (%emit-content stream (substring line pos (string-length line)) spans pos)
            (let* ((ev (car evs))
                   (start (cadr ev))
                   (end (caddr ev))
                   (piece (substring line start end))
                  ) ;
              (%emit-content stream (substring line pos start) spans pos)
              (%apply-event stream (car ev) piece (cadddr ev))
              (loop (cdr evs) end)
            ) ;let*
          ) ;if
        ) ;let
      ) ;let*-values
    ) ;define

    ;; 交付已确定的原文片段：并入栈顶结构的累积文本；
    ;; 无打开结构时作为顶层 content 事件。spans 为整行 spans，offset 为片段起点。
    (define (%emit-content stream text spans offset)
      (if (> (string-length text) 0)
        (let ((stack (structure-stream-open-stack stream)))
          (if (null? stack)
            (%emit-top-content stream text (%slice-spans spans offset text))
            (set-structure-stream-open-stack! stream
              (cons (list (caar stack) (string-append (cadar stack) text)) (cdr stack))
            ) ;set-structure-stream-open-stack!
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    ;; 顶层 content 合并：相邻 content 事件拼接为一条，
    ;; 避免逐字符输入时按传输块拆碎文本（块边界不是语义边界）。
    (define (%emit-top-content stream text spans)
      (let ((prev (structure-stream-last-content stream)))
        (if prev
          (begin
            (set-car! (cdr prev) (string-append (cadr prev) text))
            (set-car! (cddr prev) (append (caddr prev) spans))
            ;; 合并的增量同样记入原文账本。
            (%record-text stream text)
          ) ;begin
          (let ((ev (list 'content text spans)))
            (set-structure-stream-last-content! stream ev)
            (%record-text stream text)
            (%emit stream ev)
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    ;; 取整行 spans 中落在 [offset, offset+len) 的局部 spans（偏移归零）。
    (define (%slice-spans spans offset text)
      (let ((end (+ offset (string-length text))))
        (let loop
          ((rest spans) (acc '()))
          (if (null? rest)
            (reverse acc)
            (let* ((sp (car rest)) (s (car sp)) (e (+ s (cadr sp))))
              (if (and (>= s offset) (<= e end))
                (loop (cdr rest) (cons (cons (- s offset) (cdr sp)) acc))
                (loop (cdr rest) acc)
              ) ;if
            ) ;let*
          ) ;if
        ) ;let
      ) ;let
    ) ;define

    ;; 真实行尾：闭合本行打开的 line 结构（正常闭合），并交付换行符。
    (define (%finish-line stream newline)
      (let loop
        ((names (structure-stream-line-open stream)))
        (if (not (null? names)) (begin (%close-top stream #t "") (loop (cdr names))))
      ) ;let
      (set-structure-stream-line-open! stream '())
      (%emit-content stream newline '() 0)
    ) ;define

    ;; 输入一个传输块：拆出完整行处理；未完成尾部暂存到真实行尾。
    ;; 块边界不是结构边界：行级规则（keyword/Int 等）把行尾当右边界，
    ;; 部分行提前处理会误判标识符/数字，因此尾部统一暂存；
    ;; 流式输出粒度为完整行（与上游 Kate 一致）。
    (define (structure-stream-feed! stream chunk)
      (if (structure-stream-finished? stream)
        (error 'structure-stream-error "Cannot feed a finished stream")
      ) ;if
      (%feed-chunk stream chunk)
    ) ;define

    ;; 处理一个完整行（含换行符）：CRLF 的 \r 归入行尾。
    (define (%deliver-line stream line newline)
      (let ((sink (stream-line-sink stream)))
        (if sink
          (let-values (((spans next events)
                        (highlight-line-events line
                          (structure-stream-state stream)
                          (structure-stream-def stream)
                        ) ;highlight-line-events
                       ) ;
                      ) ;
            (set-structure-stream-state! stream next)
            (sink line newline spans events)
          ) ;let-values
          (begin
            (%process-line stream line)
            (%finish-line stream newline)
          ) ;begin
        ) ;if
      ) ;let
    ) ;define

    (define (%feed-line-at stream text start i)
      (let ((end
              (if
                (and (> i start) (char=? (string-ref text (- i 1)) #\return))
                (- i 1)
                i
              ) ;if
            ) ;end
           ) ;
        (%deliver-line stream (substring text start end) (substring text end (+ i 1)))
      ) ;let
    ) ;define

    (define (%feed-chunk stream chunk)
      (let ((text (string-append (structure-stream-pending stream) chunk)))
        (set-structure-stream-pending! stream "")
        (let ((len (string-length text)))
          (let loop
            ((i 0) (start 0))
            (cond ((= i len) (%keep-or-process-tail stream (substring text start len)))
                  ((char=? (string-ref text i) #\newline)
                   (%feed-line-at stream text start i)
                   (loop (+ i 1) (+ i 1))
                  ) ;
                  (else (loop (+ i 1) start))
            ) ;cond
          ) ;let
        ) ;let
      ) ;let
    ) ;define

    ;; 尾部处置：统一暂存到真实行尾或 EOF，保证行级语义不被块边界提前触发。
    (define (%keep-or-process-tail stream tail)
      (if (> (string-length tail) 0) (set-structure-stream-pending! stream tail) #f)
    ) ;define

    ;; EOF：提交暂存尾部；line 结构正常闭合；
    ;; 其余打开结构按 on-eof 策略交付（emit-unclosed / error-and-emit）。
    (define (structure-stream-finish! stream)
      (if (not (structure-stream-finished? stream))
        (begin
          (set-structure-stream-finished?! stream #t)
          (%finish-stream stream)
        ) ;begin
      ) ;if
    ) ;define

    (define (%finish-stream stream)
      (let ((pending (structure-stream-pending stream)))
        (set-structure-stream-pending! stream "")
        (when (> (string-length pending) 0)
          (if (stream-line-sink stream)
            (%deliver-line stream pending "")
            (%process-line stream pending)
          ) ;if
        ) ;when
      ) ;let
      ;; line 结构在 EOF 正常闭合
      (let loop
        ((names (structure-stream-line-open stream)))
        (if (not (null? names)) (begin (%close-top stream #t "") (loop (cdr names))))
      ) ;let
      (set-structure-stream-line-open! stream '())
      ;; 其余打开结构自内向外按策略交付
      (let loop
        ()
        (if (not (null? (structure-stream-open-stack stream)))
          (let ((sdef (caar (structure-stream-open-stack stream))))
            (if (eq? (structure-definition-on-eof sdef) 'error-and-emit)
              (%emit stream (list 'error 'unexpected-eof (structure-definition-name sdef)))
            ) ;if
            (%close-top stream #f "")
            (loop)
          ) ;let
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
