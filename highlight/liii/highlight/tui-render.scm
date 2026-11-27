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

(define-library (liii highlight tui-render)
  (import (scheme base)
    (liii base)
    (liii string)
    (liii highlight theme)
    (liii highlight definition)
    (liii highlight highlighter)
  ) ;import
  (export style->ansi-prefix render-spans-to-ansi highlight-line-to-ansi
    highlight-text-to-ansi highlight-text-to-ansi-state
  ) ;export
  (begin

    (define (append-ansi-part parts code)
      (if (pair? parts) (append parts (list ";" code)) (list code))
    ) ;define

    (define (append-color-part parts pfx-type rgb)
      (if rgb
        (let ((color-str (string-append pfx-type
                           ";2;"
                           (number->string (car rgb))
                           ";"
                           (number->string (cadr rgb))
                           ";"
                           (number->string (caddr rgb))
                         ) ;string-append
              ) ;color-str
             ) ;
          (append-ansi-part parts color-str)
        ) ;let
        parts
      ) ;if
    ) ;define

    (define (style->ansi-parts style-entry)
      (let* ((p0 '())
             (p1 (append-color-part p0 "38" (style-entry-text-color style-entry)))
             (p2 (append-color-part p1 "48" (style-entry-bg-color style-entry)))
             (p3 (if (style-entry-bold? style-entry) (append-ansi-part p2 "1") p2))
             (p4 (if (style-entry-italic? style-entry) (append-ansi-part p3 "3") p3))
             (p5 (if (style-entry-underline? style-entry) (append-ansi-part p4 "4") p4))
            ) ;
        p5
      ) ;let*
    ) ;define

    ;; ANSI 转义前缀构造
    ;; 使用 24 位真彩色（\x1b;[38;2;R;G;Bm），同时支持 bold、italic、underline
    (define (style->ansi-prefix style-entry)
      (if (not style-entry)
        ""
        (let ((parts (style->ansi-parts style-entry)))
          (if (null? parts) "" (apply string-append "\x1b;[" (append parts (list "m"))))
        ) ;let
      ) ;if
    ) ;define

    (define *ansi-reset* "\x1b;[0m")

    ;; 合并相邻且样式相同的 spans
    ;; highlighter 逐字节消耗无规则匹配的文本（例如 UTF-8 中文每个字节一个 span），
    ;; 若逐个着色，多字节字符会被转义前缀/重置码从中间打断，终端无法解码显示。
    ;; 先按 itemData 解析出样式名并合并相邻同样式 span，既保证字节序列连续，
    ;; 也减少转义序列数量。返回 '((offset length style-name) ...)
    ;; 取 span 的源定义：优先用 span 自带的（嵌入子语言），否则用外层 def
    (define (span-source-def sp fallback-def)
      (if (>= (length sp) 4) (cadddr sp) fallback-def)
    ) ;define

    (define (merge-adjacent-spans spans def)
      (let loop
        ((rest spans) (acc '()))
        (if (null? rest)
          (reverse acc)
          (let* ((sp (car rest))
                 (src-def (span-source-def sp def))
                 (style-name (definition-item-data-def-style src-def (caddr sp)))
                 (src-key (if (>= (length sp) 4) src-def #f))
                ) ;
            (if
              (and (pair? acc)
                (= (+ (car (car acc)) (cadr (car acc))) (car sp))
                (string=? (caddr (car acc)) style-name)
              ) ;and
              ;; 与前一个 span 相邻且同样式：合并长度
              (loop (cdr rest)
                (cons
                  (list (car (car acc))
                    (+ (cadr (car acc)) (cadr sp))
                    (caddr (car acc))
                    (if (>= (length (car acc)) 4) (cadddr (car acc)) src-def)
                  ) ;list
                  (cdr acc)
                ) ;cons
              ) ;loop
              (loop (cdr rest)
                (cons (list (car sp) (cadr sp) style-name (if src-key src-def #f)) acc)
              ) ;loop
            ) ;if
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    ;; 将单行的 spans 序列渲染为带有 ANSI 颜色的完整字符串
    (define (render-spans-to-ansi line spans th def)
      (let loop
        ((rest (merge-adjacent-spans spans def)) (acc '()))
        (if (null? rest)
          (apply string-append (reverse acc))
          (let* ((sp (car rest))
                 (offset (car sp))
                 (len (cadr sp))
                 (style-name (caddr sp))
                 (piece (substring line offset (+ offset len)))
                 ;; 查主题得到样式
                 (style (theme-text-style th style-name))
                 (prefix (style->ansi-prefix style))
                 (rendered-piece (if (string-null? prefix) piece (string-append prefix piece *ansi-reset*))
                 ) ;rendered-piece
                ) ;
            (loop (cdr rest) (cons rendered-piece acc))
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    ;; 单行高亮便捷函数：(highlight-line-to-ansi line state def th)
    ;; 返回 (values rendered-line next-state)
    (define (highlight-line-to-ansi line state def th)
      (let-values (((spans next-state) (highlight-line line state def)))
        (values (render-spans-to-ansi line spans th def) next-state)
      ) ;let-values
    ) ;define

    ;; 整段文本高亮为带 ANSI 颜色的字符串
    (define (highlight-text-to-ansi text def th)
      (let-values (((rendered _)
                    (highlight-text-to-ansi-state text (initial-highlight-state def) def th)
                   ) ;
                  ) ;
        rendered
      ) ;let-values
    ) ;define

    ;; 携带跨段状态的多行渲染：返回 (values rendered next-state)。
    ;; 与 highlight-text-to-ansi 逐行语义一致，但状态可跨调用延续，
    ;; 供流式渲染适配器分段使用（多行字符串/注释跨段不丢失上下文）。
    (define (highlight-text-to-ansi-state text state def th)
      (let ((lines (split-text-lines-private text)))
        (let loop
          ((ls lines) (st state) (acc '()))
          (if (null? ls)
            (values (string-join (reverse acc) "\n") st)
            (let-values (((spans next-state) (highlight-line (car ls) st def)))
              (loop (cdr ls)
                next-state
                (cons (render-spans-to-ansi (car ls) spans th def) acc)
              ) ;loop
            ) ;let-values
          ) ;if
        ) ;let
      ) ;let
    ) ;define

    ;; 与 highlighter 的 split-text-lines 同语义：保留末尾空行。
    (define (split-text-lines-private text)
      (let ((len (string-length text)))
        (let loop
          ((i 0) (start 0) (lines '()))
          (cond
           ((= i len) (reverse (cons (substring text start len) lines)))
           ((char=? (string-ref text i) #\newline)
            (let ((end
                    (if
                      (and (> i start) (char=? (string-ref text (- i 1)) #\return))
                      (- i 1)
                      i
                    ) ;if
                  ) ;end
                 ) ;
              (loop (+ i 1) (+ i 1) (cons (substring text start end) lines))
            ) ;let
           ) ;
           (else (loop (+ i 1) start lines))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
