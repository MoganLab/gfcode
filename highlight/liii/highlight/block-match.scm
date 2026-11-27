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

(define-library (liii highlight block-match)
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
  ) ;import
  (export %blank-line? %match-line-block %line-block-definitions %fence-close?)
  (begin
    (define (%blank-line? line)
      (let ((len (string-length line)))
        (let loop
          ((i 0))
          (cond ((= i len) #t)
                ((memv (string-ref line i) '(#\space #\tab #\return #\newline)) (loop (+ i 1)))
                (else #f)
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%line-indent line max-indent)
      (let ((len (string-length line)))
        (let loop
          ((i 0))
          (cond
           ((and (< i len) (< i max-indent) (char=? (string-ref line i) #\space))
            (loop (+ i 1))
           ) ;
           (else i)
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%list-start? line matcher indent)
      (let ((kind (json-ref-string matcher "kind" ""))
            (len (string-length line))
            (chars (json-ref-string matcher "chars" ""))
            (terms (json-ref-string matcher "terminators" ""))
           ) ;
        (cond
         ((string=? kind "unordered")
          (and (< (+ indent 1) len)
            (string-index chars (string-ref line indent))
            (memv (string-ref line (+ indent 1)) '(#\space #\tab))
          ) ;and
         ) ;
         ((string=? kind "ordered")
          (let loop
            ((i indent))
            (cond
             ((and (< i len) (char-numeric? (string-ref line i))) (loop (+ i 1)))
             ((and (> i indent)
                (< (+ i 1) len)
                (string-index terms (string-ref line i))
                (memv (string-ref line (+ i 1)) '(#\space #\tab))
              ) ;and
              #t
             ) ;
             (else #f)
            ) ;cond
          ) ;let
         ) ;
         (else #f)
        ) ;cond
      ) ;let
    ) ;define

    (define (%fence-run line indent minimum)
      (let ((len (string-length line)) (ch (string-ref line indent)))
        (let loop
          ((i indent))
          (if (and (< i len) (char=? (string-ref line i) ch))
            (loop (+ i 1))
            (and (>= (- i indent) minimum) (list ch (- i indent) i))
          ) ;if
        ) ;let
      ) ;let
    ) ;define

    (define (%fence-start? line matcher indent)
      (let ((chars (json-ref-string matcher "chars" ""))
            (minimum (json-ref-integer matcher "minimum" 3))
            (len (string-length line))
           ) ;
        (and (< indent len)
          (string-index chars (string-ref line indent))
          (%fence-run line indent minimum)
        ) ;and
      ) ;let
    ) ;define

    ;; 返回 (definition captured)，没有命中返回 #f。
    (define (%line-block-definitions def)
      (let ((items (json-ref (definition-line-blocks def) "definitions")))
        (if (vector? items) (vector->list items) items)
      ) ;let
    ) ;define

    (define (%match-line-block line definitions)
      (let loop
        ((rest definitions))
        (if (null? rest)
          #f
          (let* ((d (car rest))
                 (matcher (json-ref d "start"))
                 (indent (%line-indent line (json-ref-integer matcher "max-indent" 3)))
                 (kind (json-ref-string matcher "kind" ""))
                 (captured
                   (cond ((or (string=? kind "ordered") (string=? kind "unordered"))
                          (%list-start? line matcher indent)
                         ) ;
                         ((string=? kind "fence") (%fence-start? line matcher indent))
                         (else #f)
                   ) ;cond
                 ) ;captured
                ) ;
            (if captured (list d captured) (loop (cdr rest)))
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    (define (%fence-close? line frame)
      (let* ((d (car frame))
             (captured (cadr frame))
             (matcher (json-ref d "end"))
             (end
               (and (json-object? matcher)
                 (%fence-start? line
                   matcher
                   (%line-indent line (json-ref-integer matcher "max-indent" 3))
                 ) ;%fence-start?
               ) ;and
             ) ;end
            ) ;
        (and end
          (char=? (car end) (car captured))
          (>= (cadr end) (cadr captured))
          (%blank-line? (substring line (caddr end) (string-length line)))
        ) ;and
      ) ;let*
    ) ;define

    ;; 渲染一个叶子，跨调用延续宿主语言的高亮状态。
  ) ;begin
) ;define-library
