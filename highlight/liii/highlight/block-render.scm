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

(define-library (liii highlight block-render)
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
    (liii highlight block-match)
    (only (liii highlight code-block) %normalize-code-lang)
  ) ;import
  (export %highlight-port-to-ansi-block %make-markdown-block-feed)
  (begin
    (define (%render-block-leaf text state def th emit-block)
      (if (not th)
        (begin
          (emit-block text)
          state
        ) ;begin
        (let-values (((rendered next-state) (highlight-text-to-ansi-state text state def th)))
          (emit-block rendered)
          next-state
        ) ;let-values
      ) ;if
    ) ;define

    (define (%line-without-newline line)
      (let ((end (- (string-length line) 1)))
        (if
          (and (> end 0) (char=? (string-ref line (- end 1)) #\return))
          (substring line 0 (- end 1))
          (substring line 0 end)
        ) ;if
      ) ;let
    ) ;define

    (define (%render-block-line line state def th emit-block)
      (if (not th)
        (begin
          (emit-block line)
          state
        ) ;begin
        (let* ((trailing-newline?
                 (and (> (string-length line) 0)
                   (char=? (string-ref line (- (string-length line) 1)) #\newline)
                 ) ;and
               ) ;trailing-newline?
               (body (if trailing-newline? (%line-without-newline line) line))
              ) ;
          (let-values (((rendered next-state) (highlight-line-to-ansi body state def th)))
            (emit-block (if trailing-newline? (string-append rendered "\n") rendered))
            next-state
          ) ;let-values
        ) ;let*
      ) ;if
    ) ;define

    (define (%line-block-language-name line captured children)
      (let ((info (substring line (caddr captured) (string-length line))))
        (string-downcase (string-trim-both info))
      ) ;let
    ) ;define

    (define (%json-values-list values)
      (cond ((vector? values) (vector->list values))
            ((list? values) values)
            (else '())
      ) ;cond
    ) ;define

    (define (%line-block-aliases children name)
      (let ((raw (json-ref children "aliases")))
        (if (json-object? raw)
          (let loop
            ((keys (json-keys raw)))
            (if (null? keys)
              name
              (if
                (member name (%json-values-list (json-ref raw (car keys))) string=?)
                (car keys)
                (loop (cdr keys))
              ) ;if
            ) ;if
          ) ;let
          name
        ) ;if
      ) ;let
    ) ;define

    (define (%line-block-child-definition children name)
      (if (or (string-null? name) (not children))
        #f
        (guard (err (else #f))
          (let ((lang (%normalize-code-lang (%line-block-aliases children name))))
            (and lang (load-syntax-definition lang))
          ) ;let
        ) ;guard
      ) ;if
    ) ;define

    ;; children 声明嵌入语言时，父 fence 不整体计费；开始/结束 fence
    ;; 是叶子，内容递归交给子语言的 block 规则。
    (define (%close-line-block-child text close-start closed? state def th emit-block)
      (if closed?
        (%render-block-line (substring text close-start) state def th emit-block)
        state
      ) ;if
    ) ;define

    (define (%emit-embedded-block text open-end close-start closed? child state
              def th emit-block chunk-size
            ) ;%emit-embedded-block
      (let ((open-line (substring text 0 open-end))
            (content (substring text open-end close-start))
           ) ;
        (let ((next-state (%render-block-line open-line state def th emit-block)))
          (if (string-null? content)
            #f
            (%highlight-port-to-ansi-block (open-input-string content)
              (open-output-string)
              child
              th
              emit-block
              chunk-size
            ) ;%highlight-port-to-ansi-block
          ) ;if
          (%close-line-block-child text close-start closed? next-state def th emit-block)
        ) ;let
      ) ;let
    ) ;define

    (define (%line-block-close-start text closed? open-end)
      (if closed?
        (let ((last-start (string-index-right text #\newline (- (string-length text) 2))))
          (if last-start (+ last-start 1) open-end)
        ) ;let
        (string-length text)
      ) ;if
    ) ;define

    (define (%emit-line-block-children text frame state def th emit-block chunk-size)
      (let* ((captured (cadr frame))
             (children (json-ref (car frame) "children"))
             (first-end (or (string-index text #\newline) (string-length text)))
             (open-end (if (< first-end (string-length text)) (+ first-end 1) first-end))
             (open-line (substring text 0 open-end))
             (closed? (caddr frame))
             (close-start (%line-block-close-start text closed? open-end))
             (child (%line-block-child-definition children
                      (%line-block-language-name open-line captured children)
                    ) ;%line-block-child-definition
             ) ;child
            ) ;
        (if child
          (%emit-embedded-block text open-end close-start closed? child state
            def th emit-block chunk-size
          ) ;%emit-embedded-block
          (%render-block-leaf text state def th emit-block)
        ) ;if
      ) ;let*
    ) ;define

    (define (%flush-line-block lines frame closed? state def th emit-block chunk-size)
      (let ((text (apply string-append (reverse lines))))
        (if (and frame (json-ref (car frame) "children"))
          (%emit-line-block-children text
            (list (car frame) (cadr frame) closed?)
            state
            def
            th
            emit-block
            chunk-size
          ) ;%emit-line-block-children
          (%render-block-leaf text state def th emit-block)
        ) ;if
      ) ;let
    ) ;define

    ;; The same state machine drives cat's port and pi's provider deltas.
    ;; With no theme, deliver raw leaves instead of encoding them as ANSI.
    (define (%make-markdown-block-feed def th emit-block chunk-size . skipped)
      (let ((pending "") (lines '()) (frame #f) (state (initial-highlight-state def)))
        (define (flush-block! . opts)
          (let ((closed? (and (pair? opts) (car opts))))
            (if (pair? lines)
              (set! state
                (%flush-line-block lines frame closed? state def th emit-block chunk-size)
              ) ;set!
              #f
            ) ;if
          ) ;let
          (set! lines '())
          (set! frame #f)
        ) ;define
        (define (accept-line! line)
          (let ((match (%match-line-block line (%line-block-definitions def))))
            (cond (frame (set! lines (cons line lines))
                    (if (%fence-close? line frame) (flush-block! #t) #f)
                  ) ;frame
                  ((and match (string=? (json-ref-string (car match) "end" "") "next-block"))
                   (flush-block!)
                   (set! lines (list line))
                  ) ;
                  (match (flush-block!) (set! frame match) (set! lines (list line)))
                  ((and (json-ref-boolean (definition-line-blocks def) "blank-separator" #t)
                     (%blank-line? line)
                   ) ;and
                   (if (pair? lines)
                     (begin
                       (set! lines (cons line lines))
                       (flush-block!)
                     ) ;begin
                     (if (json-ref-boolean (definition-line-blocks def) "leading-blank-block" #t)
                       (set! lines (list line))
                       (when (pair? skipped)
                         ((car skipped) line)
                       ) ;when
                     ) ;if
                   ) ;if
                  ) ;
                  (else (set! lines (cons line lines)))
            ) ;cond
          ) ;let
        ) ;define
        (define (accept-chunk! chunk)
          (let ((text (string-append pending chunk)))
            (set! pending "")
            (let ((len (string-length text)))
              (let loop
                ((start 0) (i 0))
                (cond ((= i len) (set! pending (substring text start len)))
                      ((char=? (string-ref text i) #\newline)
                       (accept-line! (substring text start (+ i 1)))
                       (loop (+ i 1) (+ i 1))
                      ) ;
                      (else (loop start (+ i 1)))
                ) ;cond
              ) ;let
            ) ;let
          ) ;let
        ) ;define
        (lambda (chunk final?)
          (accept-chunk! chunk)
          (when final?
            (unless (string-null? pending)
              (accept-line! pending)
            ) ;unless
            (set! pending "")
            (flush-block!)
          ) ;when
        ) ;lambda
      ) ;let
    ) ;define

    ;; block 模式：声明了 line-blocks 时按配置切分，否则使用配对结构流。
    (define (%highlight-port-to-ansi-block in out def th emit-block chunk-size)
      (cond
       ((pair? (%line-block-definitions def))
        (let ((feed (%make-markdown-block-feed def th emit-block chunk-size)))
          (let loop
            ()
            (let ((chunk (read-string chunk-size in)))
              (if (or (eof-object? chunk) (string-null? chunk))
                (feed "" #t)
                (begin
                  (feed chunk #f)
                  (loop)
                ) ;begin
              ) ;if
            ) ;let
          ) ;let
        ) ;let
       ) ;
       ((pair? (structure-set-structures (definition-structures def)))
        (highlight-port-to-ansi-structure-block in out def th emit-block chunk-size)
       ) ;
       (else (highlight-port-to-ansi-plain-block in def th emit-block chunk-size))
      ) ;cond
    ) ;define

    (define (highlight-port-to-ansi-plain-block in def th emit-block chunk-size)
      (let ((pending "") (state (initial-highlight-state def)))
        (define (accept-chunk! chunk)
          (let ((text (string-append pending chunk)))
            (set! pending "")
            (let ((len (string-length text)))
              (let loop
                ((start 0) (i 0))
                (cond ((= i len) (set! pending (substring text start len)))
                      ((char=? (string-ref text i) #\newline)
                       (set! state
                         (%render-block-leaf (substring text start (+ i 1)) state def th emit-block)
                       ) ;set!
                       (loop (+ i 1) (+ i 1))
                      ) ;
                      (else (loop start (+ i 1)))
                ) ;cond
              ) ;let
            ) ;let
          ) ;let
        ) ;define
        (let loop
          ()
          (let ((chunk (read-string chunk-size in)))
            (if (or (eof-object? chunk) (string-null? chunk))
              (if (string-null? pending)
                #f
                (%render-block-leaf pending state def th emit-block)
              ) ;if
              (begin
                (accept-chunk! chunk)
                (loop)
              ) ;begin
            ) ;if
          ) ;let
        ) ;let
      ) ;let
    ) ;define

    (define (%accept-structure-piece piece event state pending-close flush-close
              def th emit-block
            ) ;%accept-structure-piece
      (cond
       ((and (not (string-null? (car pending-close))) (string=? piece "\n"))
        (set-car! pending-close (string-append (car pending-close) piece))
        (flush-close)
        state
       ) ;
       ((eq? (car event) 'close) (flush-close) (set-car! pending-close piece) state)
       (else (flush-close) (%render-block-leaf piece state def th emit-block))
      ) ;cond
    ) ;define

    (define (highlight-port-to-ansi-structure-block in out def th emit-block chunk-size)
      (let* ((delivered (list 0))
             (stream-box (list #f))
             (state (initial-highlight-state def))
             (pending-close (list ""))
             (flush-close
               (lambda ()
                 (if (string-null? (car pending-close))
                   #f
                   (begin
                     (set! state (%render-block-leaf (car pending-close) state def th emit-block))
                     (set-car! pending-close "")
                   ) ;begin
                 ) ;if
               ) ;lambda
             ) ;flush-close
             (emit-delta
               (lambda (stream event)
                 (let* ((text (structure-stream-text stream))
                        (from (car delivered))
                        (to (string-length text))
                       ) ;
                   (if (> to from)
                     (begin
                       (set! state
                         (%accept-structure-piece (substring text from to)
                           event
                           state
                           pending-close
                           flush-close
                           def
                           th
                           emit-block
                         ) ;%accept-structure-piece
                       ) ;set!
                       (set-car! delivered to)
                     ) ;begin
                     #f
                   ) ;if
                 ) ;let*
               ) ;lambda
             ) ;emit-delta
             (stream
               (make-structure-stream def
                 ;; 每个事件后检查账本增量：合并进上一条 content 的文本
                 ;; 不再产生新事件，也必须在此时交付。
                 (lambda (ev) (emit-delta (car stream-box) ev))
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
                ;; EOF 收尾：交付最后一次 content 合并产生的增量。
                (emit-delta stream '(content))
                (flush-close)
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
  ) ;begin
) ;define-library
