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

(define-library (liii highlight stream-ansi)
  (import (scheme base)
    (scheme char)
    (liii base)
    (liii string)
    (liii json)
    (liii highlight structure)
    (liii highlight definition)
    (liii highlight theme)
    (liii highlight highlighter)
    (liii highlight tui-render)
    (liii highlight stream)
    (liii highlight block-render)
  ) ;import
  (export make-ansi-structure-emitter ansi-structure-emitter?
    ansi-structure-emitter-feed! highlight-port-to-ansi-streaming
    highlight-port-to-ansi-mode
  ) ;export
  (begin

    ;; 结构事件 → ANSI 文本适配器。
    ;; 只渲染完整行（以 \n 结尾），不完整尾行留待后续，
    ;; 避免在行中切断关键字/标识符；跨段高亮状态延续，
    ;; 多行字符串/注释跨段不丢失上下文。
    ;; final? 为 #t（EOF）时连不完整尾行一起渲染，不补换行。

    (define*-record-type <ansi-structure-emitter>
      (make-ansi-structure-emitter def th emit-text (rendered 0) (render-state #f))
      ansi-structure-emitter?
      (def ansi-emitter-def)
      (th ansi-emitter-th)
      (emit-text ansi-emitter-emit-text)
      (rendered ansi-emitter-rendered set-ansi-emitter-rendered!)
      (render-state ansi-emitter-render-state set-ansi-emitter-render-state!)
    ) ;define*-record-type

    ;; 渲染 piece（完整行集合，含末尾换行或不完整尾行）。
    (define (%render-piece emitter piece)
      (let* ((def (ansi-emitter-def emitter))
             (state (or (ansi-emitter-render-state emitter) (initial-highlight-state def)))
            ) ;
        (let-values (((rendered next-state)
                      (highlight-text-to-ansi-state piece state def (ansi-emitter-th emitter))
                     ) ;
                    ) ;
          (set-ansi-emitter-render-state! emitter next-state)
          rendered
        ) ;let-values
      ) ;let*
    ) ;define

    ;; 事件回调：渲染结构流原文账本的新增完整行；final? 时含尾行。
    (define (ansi-structure-emitter-feed! emitter stream event . opts)
      (let* ((final? (and (not (null? opts)) (car opts)))
             (text (structure-stream-text stream))
             (from (ansi-emitter-rendered emitter))
             (to (string-length text))
             (end
               (if final?
                 to
                 (let loop
                   ((i to))
                   (cond ((<= i from) from)
                         ((char=? (string-ref text (- i 1)) #\newline) i)
                         (else (loop (- i 1)))
                   ) ;cond
                 ) ;let
               ) ;if
             ) ;end
            ) ;
        (if (> end from)
          (let* ((piece (substring text from end))
                 ;; 末尾换行单独交付：piece 去掉末尾 \n 后渲染，
                 ;; 避免 split 产生的末尾空行多补一个换行。
                 (trailing-nl?
                   (and (> (string-length piece) 0)
                     (char=? (string-ref piece (- (string-length piece) 1)) #\newline)
                   ) ;and
                 ) ;trailing-nl?
                 (body
                   (if trailing-nl? (substring piece 0 (- (string-length piece) 1)) piece)
                 ) ;body
                 (rendered (%render-piece emitter body))
                 (out-text (if trailing-nl? (string-append rendered "\n") rendered))
                ) ;
            ((ansi-emitter-emit-text emitter) out-text)
            (set-ansi-emitter-rendered! emitter end)
          ) ;let*
        ) ;if
      ) ;let*
    ) ;define

    ;; 端口级流式高亮：按块读取输入端口，结构事件驱动 ANSI 输出。
    ;; 不等整个文件；已确定的完整行即时渲染。chunk-size 默认 8192 字符。
    ;; 可选第二个参数为自定义输出过程（如限速 sink）。
    (define (highlight-port-to-ansi-streaming in out def th . opts)
      (let* ((chunk-size (if (null? opts) 8192 (car opts)))
             (emit (if (> (length opts) 1) (cadr opts) (lambda (t) (display t out))))
             (emitter (make-ansi-structure-emitter def th emit))
             (stream-box (list #f))
             (stream
               (make-structure-stream def
                 (lambda (ev) (ansi-structure-emitter-feed! emitter (car stream-box) ev))
               ) ;make-structure-stream
             ) ;stream
            ) ;
        (set-car! stream-box stream)
        (let loop
          ()
          (let ((chunk (read-string chunk-size in)))
            (if (or (eof-object? chunk) (string-null? chunk))
              (begin
                (structure-stream-finish! stream)
                ;; EOF：渲染尚未交付的尾行（无末尾换行）。
                (ansi-structure-emitter-feed! emitter stream '(eof) #t)
              ) ;begin
              (begin
                (structure-stream-feed! stream chunk)
                (loop)
              ) ;begin
            ) ;if
          ) ;let
        ) ;let
      ) ;let*
    ) ;define

    ;; 模式化流式高亮：
    ;;   char  按语义 token（高亮 spans 合并后的单元）交付，逐 token 计费。
    ;;   block 按语义结构片段交付（默认），每片段计费一次。
    ;; emit-block：接收完整 ANSI 片段文本的回调；emit-char 复用 emit-block 逐 token。
    (define (highlight-port-to-ansi-mode in out def th mode emit-block . opts)
      (let ((chunk-size (if (null? opts) 8192 (car opts))))
        (case mode
         ((block) (%highlight-port-to-ansi-block in out def th emit-block chunk-size))
         ((char)
          (highlight-port-to-ansi-streaming in
            out
            def
            th
            chunk-size
            (lambda (text) (emit-ansi-tokens text def th emit-block))
          ) ;highlight-port-to-ansi-streaming
         ) ;
         (else (error 'output-mode-error "Unknown output mode" mode))
        ) ;case
      ) ;let
    ) ;define

    ;; 把一段已渲染 ANSI 文本按语义 token 拆分交付：
    ;; 样式前缀 + 原文 + reset 为一个 token 单元；裸文本（无样式）各成单元。
    (define (emit-ansi-tokens text def th emit-token)
      (let ((len (string-length text)))
        (let loop
          ((i 0))
          (if (< i len)
            (if (ansi-escape-at? text i len)
              (let ((end (ansi-escape-end text i len)))
                (if (ansi-reset-at? text i end)
                  (loop end)
                  ;; 前缀起点：找到对应 reset，整段作为一个 token
                  (let ((rend (ansi-find-reset text end len)))
                    (emit-token (substring text i rend))
                    (loop rend)
                  ) ;let
                ) ;if
              ) ;let
              ;; 裸文本：到下一个转义或结尾
              (let ((end (ansi-find-escape text (+ i 1) len)))
                (emit-token (substring text i end))
                (loop end)
              ) ;let
            ) ;if
          ) ;if
        ) ;let
      ) ;let
    ) ;define

    (define (ansi-escape-at? text i len)
      (and (< (+ i 1) len)
        (char=? (string-ref text i) (integer->char 27))
        (char=? (string-ref text (+ i 1)) #\[)
      ) ;and
    ) ;define

    (define (ansi-find-escape text from len)
      (let loop
        ((j from))
        (cond ((>= j len) len)
              ((char=? (string-ref text j) (integer->char 27)) j)
              (else (loop (+ j 1)))
        ) ;cond
      ) ;let
    ) ;define

    (define (ansi-find-reset text from len)
      (let loop
        ((j from))
        (cond ((>= j len) len)
              ((and (char=? (string-ref text j) (integer->char 27))
                 (ansi-reset-at? text j (ansi-escape-end text j len))
               ) ;and
               (ansi-escape-end text j len)
              ) ;
              (else (loop (+ j 1)))
        ) ;cond
      ) ;let
    ) ;define

    (define (ansi-escape-end text i len)
      (let loop
        ((j (+ i 2)))
        (if (or (>= j len) (char=? (string-ref text j) #\m))
          (if (< j len) (+ j 1) len)
          (loop (+ j 1))
        ) ;if
      ) ;let
    ) ;define

    (define (ansi-reset-at? text i end)
      (string=? (substring text i end) "\x1b;[0m")
    ) ;define

    ;; 通用行级 block 解析器。匹配器与边界全部来自 syntax JSON，
    ;; 不判断语言名，也不内置任何语言的列表或 fence 标记。
  ) ;begin
) ;define-library
