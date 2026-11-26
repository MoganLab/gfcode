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

;; Markdown 围栏代码块的纯解析与语言解析工具，以及 IncludeRules 的子定义缓存。
;; 这些函数不触及高亮状态机与上下文栈，从 (liii highlight highlighter) 拆出，
;; 使主模块控制在 gfcheck 单文件行数上限内。

(define-library (liii highlight code-block)
  (import (scheme base)
    (scheme char)
    (liii base)
    (liii string)
    (liii hash-table)
    (liii highlight definition)
  ) ;import
  (export %extract-first-word %normalize-code-lang %resolve-sub-definition
    %rest-all-spaces? %code-block-close-line? %code-block-open-info
    %parse-code-block-open fenced-code-frame?
  ) ;export
  (begin

    (define *embedded-def-cache* (make-hash-table))

    (define (%extract-first-word str)
      (let ((len (string-length str)))
        (let loop
          ((i 0))
          (cond ((= i len) "")
                ((char-whitespace? (string-ref str i)) (loop (+ i 1)))
                (else
                  (let wloop
                    ((j i))
                    (if (or (= j len) (char-whitespace? (string-ref str j)))
                      (substring str i j)
                      (wloop (+ j 1))
                    ) ;if
                  ) ;let
                ) ;else
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%normalize-code-lang raw-lang)
      (let* ((trimmed (string-trim-both raw-lang)) (lower (string-downcase trimmed)))
        (cond ((or (string=? lower "scheme") (string=? lower "scm") (string=? lower "ss"))
               "scheme"
              ) ;
              ((or (string=? lower "c") (string=? lower "h")) "c")
              ((or (string=? lower "cpp")
                 (string=? lower "c++")
                 (string=? lower "cxx")
                 (string=? lower "cc")
                 (string=? lower "hpp")
                 (string=? lower "hxx")
                 (string=? lower "hh")
               ) ;or
               "cpp"
              ) ;
              ((string=? lower "json") "json")
              ((string=? lower "lua") "lua")
              ((or (string=? lower "markdown") (string=? lower "md")) "markdown")
              ((or (string=? lower "javascript")
                 (string=? lower "js")
                 (string=? lower "mjs")
                 (string=? lower "cjs")
                 (string=? lower "node")
               ) ;or
               "javascript"
              ) ;
              ((or (string=? lower "bash")
                 (string=? lower "sh")
                 (string=? lower "shell")
                 (string=? lower "zsh")
               ) ;or
               "bash"
              ) ;
              ((string-null? lower) #f)
              (else lower)
        ) ;cond
      ) ;let*
    ) ;define

    (define (%resolve-sub-definition lang-name)
      (if (or (not (string? lang-name)) (string-null? lang-name))
        #f
        (let ((norm (%normalize-code-lang lang-name)))
          (if (not norm)
            #f
            (if (hash-table-contains? *embedded-def-cache* norm)
              (hash-table-ref *embedded-def-cache* norm)
              (guard (err (else (hash-table-set! *embedded-def-cache* norm #f) #f))
                (let ((d (load-syntax-definition norm)))
                  (hash-table-set! *embedded-def-cache* norm d)
                  d
                ) ;let
              ) ;guard
            ) ;if
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    (define (%rest-all-spaces? text k len)
      (let loop
        ((i k))
        (cond ((= i len) #t)
              ((let ((c (string-ref text i)))
                 (or (char=? c #\space) (char=? c #\tab))
               ) ;let
               (loop (+ i 1))
              ) ;
              (else #f)
        ) ;cond
      ) ;let
    ) ;define

    (define (%code-block-close-line? text fence-char fence-len)
      (let ((len (string-length text)))
        (let loop
          ((i 0) (spaces 0))
          (cond
           ((and (< i len) (char=? (string-ref text i) #\space) (< spaces 3))
            (loop (+ i 1) (+ spaces 1))
           ) ;
           ((>= i len) #f)
           ((char=? (string-ref text i) fence-char)
            (let count-loop
              ((j i) (cnt 0))
              (if (and (< j len) (char=? (string-ref text j) fence-char))
                (count-loop (+ j 1) (+ cnt 1))
                (and (>= cnt fence-len) (%rest-all-spaces? text j len))
              ) ;if
            ) ;let
           ) ;
           (else #f)
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%code-block-open-info text j len ch cnt)
      (let ((info (substring text j len)))
        (if (and (char=? ch #\`) (string-index info #\`))
          #f
          (list ch cnt (%extract-first-word info))
        ) ;if
      ) ;let
    ) ;define

    (define (%parse-code-block-open text)
      (let ((len (string-length text)))
        (let loop
          ((i 0) (spaces 0))
          (cond
           ((and (< i len) (char=? (string-ref text i) #\space) (< spaces 3))
            (loop (+ i 1) (+ spaces 1))
           ) ;
           ((>= i len) #f)
           (else
             (let ((ch (string-ref text i)))
               (if (or (char=? ch #\`) (char=? ch #\~))
                 (let count-loop
                   ((j i) (cnt 0))
                   (if (and (< j len) (char=? (string-ref text j) ch))
                     (count-loop (+ j 1) (+ cnt 1))
                     (if (< cnt 3) #f (%code-block-open-info text j len ch cnt))
                   ) ;if
                 ) ;let
                 #f
               ) ;if
             ) ;let
           ) ;else
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (fenced-code-frame? frame)
      (and (pair? frame) (eq? (car frame) 'fenced-code))
    ) ;define

  ) ;begin
) ;define-library
