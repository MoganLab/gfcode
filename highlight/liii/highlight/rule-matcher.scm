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

;; 各规则 do-match 实现与匹配结果 record。
;; 从 (liii highlight rule) 拆出，使规则匹配逻辑与规则描述/分发分离，
;; 两者均控制在 gfcheck 单文件行数上限内。

(define-library (liii highlight rule-matcher)
  (import (scheme base) (scheme char) (liii base) (liii string) (liii hash-table))
  (export make-match-result match-result? match-result-matched?
    match-result-new-offset %no-match %matched %match-detect-char
    %match-detect-2chars %match-any-char %match-string-detect %match-word-detect
    %match-keyword %match-int %match-detect-spaces %match-detect-identifier
    %match-charset-run %match-hex %match-json-exponent %match-json-number-suffix
    %match-json-number %match-json-escape-char %match-json-escape-error
  ) ;export
  (begin

    ;; 匹配结果 record
    (define*-record-type <match-result>
      (make-match-result (matched? #f) (new-offset 0))
      match-result?
      (matched? match-result-matched?)
      (new-offset match-result-new-offset)
    ) ;define*-record-type

    (define (%no-match offset)
      (make-match-result #f offset)
    ) ;define

    (define (%matched new-offset)
      (make-match-result #t new-offset)
    ) ;define

    ;; 默认 Scheme/Kate 单词分隔符
    (define *default-delimiters* " \t\r\n()[]{}\",'`;\\")

    (define (delimiter? ch delims)
      (let ((ds (or delims *default-delimiters*)))
        (not (not (string-index ds ch)))
      ) ;let
    ) ;define

    ;; =================== 各规则 do-match 实现 ===================

    (define (%match-detect-char ch text offset text-len)
      (if (and (< offset text-len) (char=? (string-ref text offset) ch))
        (%matched (+ offset 1))
        (%no-match offset)
      ) ;if
    ) ;define

    (define (%match-detect-2chars pair text offset text-len)
      (if
        (and (<= (+ offset 2) text-len)
          (char=? (string-ref text offset) (car pair))
          (char=? (string-ref text (+ offset 1)) (cdr pair))
        ) ;and
        (%matched (+ offset 2))
        (%no-match offset)
      ) ;if
    ) ;define

    (define (%match-any-char char-bag text offset text-len)
      (if (and (< offset text-len) (string-index char-bag (string-ref text offset)))
        (%matched (+ offset 1))
        (%no-match offset)
      ) ;if
    ) ;define

    (define (%match-string-detect pat text offset text-len)
      (let ((plen (string-length pat)))
        (if
          (and (<= (+ offset plen) text-len)
            (string=? (substring text offset (+ offset plen)) pat)
          ) ;and
          (%matched (+ offset plen))
          (%no-match offset)
        ) ;if
      ) ;let
    ) ;define

    (define (%match-word-detect word delims text offset text-len)
      (let ((wlen (string-length word)))
        (if (< text-len (+ offset wlen))
          (%no-match offset)
          ;; 左边界：必须在行首或前一个字符是分隔符
          (if
            (and (> offset 0) (not (delimiter? (string-ref text (- offset 1)) delims)))
            (%no-match offset)
            ;; 比较内容
            (if
              (not (string=? (substring text offset (+ offset wlen)) word))
              (%no-match offset)
              ;; 右边界：必须在行尾或下一个字符是分隔符
              (let ((after (+ offset wlen)))
                (if (or (= after text-len) (delimiter? (string-ref text after) delims))
                  (%matched after)
                  (%no-match offset)
                ) ;if
              ) ;let
            ) ;if
          ) ;if
        ) ;if
      ) ;let
    ) ;define

    (define (%match-keyword kw-set delims text offset text-len)
      ;; 单词边界检查：若 offset > 0 且前一字符不是分隔符，不能是关键字起始
      (if
        (and (> offset 0) (not (delimiter? (string-ref text (- offset 1)) delims)))
        (%no-match offset)
        ;; 扫描直到分隔符或行尾
        (let loop
          ((i offset))
          (if (or (= i text-len) (delimiter? (string-ref text i) delims))
            (if (= i offset)
              (%no-match offset)
              (let ((word (substring text offset i)))
                (cond ((hash-table? kw-set)
                       (if (hash-table-contains? kw-set word) (%matched i) (%no-match offset))
                      ) ;
                      ((list? kw-set) (if (member word kw-set) (%matched i) (%no-match offset)))
                      (else (%no-match offset))
                ) ;cond
              ) ;let
            ) ;if
            (loop (+ i 1))
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    (define (%match-int delims text offset text-len)
      ;; 左边界检查
      (if
        (and (> offset 0) (not (delimiter? (string-ref text (- offset 1)) delims)))
        (%no-match offset)
        (let loop
          ((i offset))
          (if (and (< i text-len) (char-numeric? (string-ref text i)))
            (loop (+ i 1))
            (if (> i offset)
              ;; 右边界检查
              (if (or (= i text-len) (delimiter? (string-ref text i) delims))
                (%matched i)
                (%no-match offset)
              ) ;if
              (%no-match offset)
            ) ;if
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    ;; DetectSpaces：只匹配空格与 tab（与 Kate 一致）。
    ;; 不能用 char-whitespace?：它会把 UTF-8 多字节中文里的 0x85(NEL)、
    ;; 0xA0(NBSP) 等字节当空白切走，把汉字从中间打断导致终端无法解码。
    (define (%ascii-space-or-tab? ch)
      (or (char=? ch #\space) (char=? ch #\tab))
    ) ;define

    (define (%match-detect-spaces text offset text-len)
      (let loop
        ((i offset))
        (if (and (< i text-len) (%ascii-space-or-tab? (string-ref text i)))
          (loop (+ i 1))
          (if (> i offset) (%matched i) (%no-match offset))
        ) ;if
      ) ;let
    ) ;define

    (define (%match-detect-identifier delims text offset text-len)
      (if (>= offset text-len)
        (%no-match offset)
        (let ((c (string-ref text offset)))
          (if (or (char-alphabetic? c) (char=? c #\_))
            (let loop
              ((i (+ offset 1)))
              (if
                (and (< i text-len)
                  (let ((ci (string-ref text i)))
                    (or (char-alphabetic? ci) (char-numeric? ci) (char=? ci #\_))
                  ) ;let
                ) ;and
                (loop (+ i 1))
                (%matched i)
              ) ;if
            ) ;let
            (%no-match offset)
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    ;; 字符集连续扫描：只要属于 chars-bag 就一直往前吞，吞够 min-count 算成功
    (define (%match-charset-run bag-or-pred min-count text offset text-len)
      (let loop
        ((i offset))
        (if
          (and (< i text-len)
            (if (string? bag-or-pred)
              (not (not (string-index bag-or-pred (string-ref text i))))
              (bag-or-pred (string-ref text i))
            ) ;if
          ) ;and
          (loop (+ i 1))
          (if (>= (- i offset) min-count) (%matched i) (%no-match offset))
        ) ;if
      ) ;let
    ) ;define

    (define (%word-char? ch)
      (or (and (char>=? ch #\a) (char<=? ch #\z))
        (and (char>=? ch #\A) (char<=? ch #\Z))
        (and (char>=? ch #\0) (char<=? ch #\9))
        (char=? ch #\_)
      ) ;or
    ) ;define

    (define (%hex-digit? ch)
      (or (and (char>=? ch #\0) (char<=? ch #\9))
        (and (char>=? ch #\a) (char<=? ch #\f))
        (and (char>=? ch #\A) (char<=? ch #\F))
      ) ;or
    ) ;define

    (define (%match-hex text offset text-len)
      (if
        (and (< (+ offset 2) text-len)
          (char=? (string-ref text offset) #\0)
          (let ((x (string-ref text (+ offset 1))))
            (or (char=? x #\x) (char=? x #\X))
          ) ;let
          (%hex-digit? (string-ref text (+ offset 2)))
        ) ;and
        (let loop
          ((i (+ offset 3)))
          (if
            (and (< i text-len)
              (or (%hex-digit? (string-ref text i)) (char=? (string-ref text i) #\'))
            ) ;and
            (loop (+ i 1))
            (let suffix-loop
              ((j i))
              (if
                (and (< j text-len)
                  (let ((c (string-ref text j)))
                    (or (char=? c #\u) (char=? c #\U) (char=? c #\l) (char=? c #\L))
                  ) ;let
                ) ;and
                (suffix-loop (+ j 1))
                (%matched j)
              ) ;if
            ) ;let
          ) ;if
        ) ;let
        (%no-match offset)
      ) ;if
    ) ;define

    (define (%match-json-exponent text offset base-end text-len)
      (if
        (and (< base-end text-len)
          (let ((ch (string-ref text base-end)))
            (or (char=? ch #\e) (char=? ch #\E))
          ) ;let
        ) ;and
        (let* ((e1 (+ base-end 1))
               (e-digit
                 (if
                   (and (< e1 text-len)
                     (let ((s (string-ref text e1)))
                       (or (char=? s #\+) (char=? s #\-))
                     ) ;let
                   ) ;and
                   (+ e1 1)
                   e1
                 ) ;if
               ) ;e-digit
              ) ;
          (if (and (< e-digit text-len) (char-numeric? (string-ref text e-digit)))
            (let loop
              ((k (+ e-digit 1)))
              (if (and (< k text-len) (char-numeric? (string-ref text k)))
                (loop (+ k 1))
                (%matched k)
              ) ;if
            ) ;let
            (%matched base-end)
          ) ;if
        ) ;let*
        (%matched base-end)
      ) ;if
    ) ;define

    (define (%match-json-number-suffix is-float? text offset int-end text-len)
      (let* ((has-dot? (and (< int-end text-len) (char=? (string-ref text int-end) #\.)))
             (has-frac?
               (and has-dot?
                 (< (+ int-end 1) text-len)
                 (char-numeric? (string-ref text (+ int-end 1)))
               ) ;and
             ) ;has-frac?
             (frac-end
               (if has-frac?
                 (let loop
                   ((j (+ int-end 2)))
                   (if (and (< j text-len) (char-numeric? (string-ref text j))) (loop (+ j 1)) j)
                 ) ;let
                 #f
               ) ;if
             ) ;frac-end
            ) ;
        (if is-float?
          (if (not frac-end)
            (%no-match offset)
            (%match-json-exponent text offset frac-end text-len)
          ) ;if
          (if frac-end
            (%no-match offset)
            (%match-json-exponent text offset int-end text-len)
          ) ;if
        ) ;if
      ) ;let*
    ) ;define

    (define (%match-json-number is-float? text offset text-len)
      (if
        (and (> offset 0) (%word-char? (string-ref text (- offset 1))))
        (%no-match offset)
        (let ((i
                (if (and (< offset text-len) (char=? (string-ref text offset) #\-))
                  (+ offset 1)
                  offset
                ) ;if
              ) ;i
             ) ;
          (if (>= i text-len)
            (%no-match offset)
            (let ((c (string-ref text i)))
              (cond
               ((char=? c #\0)
                (if
                  (and (< (+ i 1) text-len) (%word-char? (string-ref text (+ i 1))))
                  (%no-match offset)
                  (%match-json-number-suffix is-float? text offset (+ i 1) text-len)
                ) ;if
               ) ;
               ((and (char>=? c #\1) (char<=? c #\9))
                (let loop
                  ((j (+ i 1)))
                  (if (and (< j text-len) (char-numeric? (string-ref text j)))
                    (loop (+ j 1))
                    (%match-json-number-suffix is-float? text offset j text-len)
                  ) ;if
                ) ;let
               ) ;
               (else (%no-match offset))
              ) ;cond
            ) ;let
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    (define (%match-json-escape-char text offset text-len)
      (if (and (< (+ offset 1) text-len) (char=? (string-ref text offset) #\\))
        (let ((c (string-ref text (+ offset 1))))
          (cond ((or (char=? c #\")
                   (char=? c #\\)
                   (char=? c #\/)
                   (char=? c #\b)
                   (char=? c #\f)
                   (char=? c #\n)
                   (char=? c #\r)
                   (char=? c #\t)
                 ) ;or
                 (%matched (+ offset 2))
                ) ;
                ((and (or (char=? c #\u) (char=? c #\U))
                   (<= (+ offset 6) text-len)
                   (%hex-digit? (string-ref text (+ offset 2)))
                   (%hex-digit? (string-ref text (+ offset 3)))
                   (%hex-digit? (string-ref text (+ offset 4)))
                   (%hex-digit? (string-ref text (+ offset 5)))
                 ) ;and
                 (%matched (+ offset 6))
                ) ;
                (else (%no-match offset))
          ) ;cond
        ) ;let
        (%no-match offset)
      ) ;if
    ) ;define

    (define (%match-json-escape-error text offset text-len)
      (if (and (< offset text-len) (char=? (string-ref text offset) #\\))
        (if (>= (+ offset 1) text-len)
          (%matched (+ offset 1))
          (let ((c (string-ref text (+ offset 1))))
            (if (or (char=? c #\u) (char=? c #\U))
              (let loop
                ((k (+ offset 2)))
                (if (and (< k text-len) (%hex-digit? (string-ref text k)))
                  (loop (+ k 1))
                  (%matched k)
                ) ;if
              ) ;let
              (%matched (+ offset 2))
            ) ;if
          ) ;let
        ) ;if
        (%no-match offset)
      ) ;if
    ) ;define

  ) ;begin
) ;define-library
