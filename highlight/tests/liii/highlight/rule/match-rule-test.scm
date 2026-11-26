;; match-rule
;; 对单条规则执行匹配。
;;
;; 语法
;; ----
;; (match-rule r text offset text-len first-non-space)
;;
;; 参数
;; ----
;; r : rule?
;; 规则对象。
;;
;; text : string
;; 当前行的文本。
;;
;; offset : integer
;; 匹配起始偏移。
;;
;; text-len : integer
;; 文本长度。
;;
;; first-non-space : integer
;; 行首第一个非空白字符索引。
;;
;; 返回值
;; ----
;; <match-result>
;; 匹配结果。

(import (scheme base)
  (liii check)
  (liii highlight rule)
  (liii highlight rule-matcher)
) ;import

(check-set-mode! 'report-failed)

;; DetectChar
(let ((r (make-rule 'detect-char "Brackets" '(stay) #\()))
  (let ((res (match-rule r "(+ 1 2)" 0 7 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 1)
  ) ;let
  (check-false (match-result-matched? (match-rule r "(+ 1 2)" 1 7 0)))
) ;let

;; Detect2Chars
(let ((r (make-rule 'detect-2chars "Comment" '(stay) (cons #\# #\|))))
  (let ((res (match-rule r "#| block |#" 0 11 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 2)
  ) ;let
) ;let

;; AnyChar
(let ((r (make-rule 'any-char "Operator" '(stay) "{}[]")))
  (check-true (match-result-matched? (match-rule r "[1]" 0 3 0)))
  (check-false (match-result-matched? (match-rule r "a1]" 0 3 0)))
) ;let

;; StringDetect
(let ((r (make-rule 'string-detect "Region" '(stay) "BEGIN")))
  (let ((res (match-rule r ";; BEGIN region" 3 15 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 8)
  ) ;let
) ;let

;; WordDetect：词边界
(let ((r (make-rule 'word-detect "Char" '(stay) (cons "space" #f))))
  (check-true (match-result-matched? (match-rule r "space" 0 5 0)))
  (check-false (match-result-matched? (match-rule r "spaceship" 0 10 0)))
) ;let

;; Keyword：命中与边界
(let ((r (make-rule 'keyword "Keyword" '(stay) (cons '("define" "lambda" "if") #f))))
  (let ((res (match-rule r "define x 1" 0 10 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 6)
  ) ;let
  ;; 前缀匹配但不独立词 -> 不命中
  (check-false (match-result-matched? (match-rule r "defines x 1" 0 11 0)))
  ;; 词中间起始 -> 不命中
  (check-false (match-result-matched? (match-rule r "xdefine" 1 7 0)))
) ;let

;; Int
(let ((r (make-rule 'int "Decimal" '(stay) #f)))
  (let ((res (match-rule r "12345" 0 5 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 5)
  ) ;let
  ;; 右边界不是分隔符 -> 不命中
  (check-false (match-result-matched? (match-rule r "123a" 0 4 0)))
) ;let

;; DetectSpaces
(let ((r (make-rule 'detect-spaces "Normal" '(stay) #t)))
  (let ((res (match-rule r "   hello" 0 8 3)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 3)
  ) ;let
  (check-false (match-result-matched? (match-rule r "hello" 0 5 0)))
) ;let

;; DetectIdentifier
(let ((r (make-rule 'detect-identifier "Normal" '(stay) #f)))
  (let ((res (match-rule r "foo42+" 0 6 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 5)
  ) ;let
  (check-false (match-result-matched? (match-rule r "42foo" 0 5 0)))
) ;let

;; CharsetRun
(let ((r (make-rule 'charset-run "Comment" '(stay) (cons "; \t" 1))))
  (let ((res (match-rule r ";;;   hello" 0 11 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 6)
  ) ;let
) ;let

;; Float
(let ((r (make-rule 'float "Float" '(stay) #f)))
  (let ((res (match-rule r "3.1415," 0 7 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 6)
  ) ;let
  (let ((res-neg (match-rule r "-0.01" 0 5 0)))
    (check-true (match-result-matched? res-neg))
    (check (match-result-new-offset res-neg) => 5)
  ) ;let
  ;; 无小数点不是 float
  (check-false (match-result-matched? (match-rule r "123" 0 3 0)))
  ;; 前导零且后跟数字不是合法数字
  (check-false (match-result-matched? (match-rule r "00.1" 0 4 0)))
) ;let

;; Decimal
(let ((r (make-rule 'decimal "DecVal" '(stay) #f)))
  (let ((res (match-rule r "123," 0 4 0)))
    (check-true (match-result-matched? res))
    (check (match-result-new-offset res) => 3)
  ) ;let
  (let ((res-zero (match-rule r "0," 0 2 0)))
    (check-true (match-result-matched? res-zero))
    (check (match-result-new-offset res-zero) => 1)
  ) ;let
  (let ((res-neg (match-rule r "-0," 0 3 0)))
    (check-true (match-result-matched? res-neg))
    (check (match-result-new-offset res-neg) => 2)
  ) ;let
  ;; 00 非法
  (check-false (match-result-matched? (match-rule r "00" 0 2 0)))
  ;; 带小数点的交由 float 处理
  (check-false (match-result-matched? (match-rule r "1.23" 0 4 0)))
) ;let

;; JsonEscapeChar
(let ((r (make-rule 'json-escape-char "Char" '(stay) #f)))
  (let ((res1 (match-rule r "\\n" 0 2 0)))
    (check-true (match-result-matched? res1))
    (check (match-result-new-offset res1) => 2)
  ) ;let
  (let ((res2 (match-rule r "\\u0042" 0 6 0)))
    (check-true (match-result-matched? res2))
    (check (match-result-new-offset res2) => 6)
  ) ;let
  ;; 无效转义序列不匹配
  (check-false (match-result-matched? (match-rule r "\\a" 0 2 0)))
  (check-false (match-result-matched? (match-rule r "\\u00P" 0 5 0)))
) ;let

;; JsonEscapeError
(let ((r (make-rule 'json-escape-error "Error" '(stay) #f)))
  (let ((res1 (match-rule r "\\a" 0 2 0)))
    (check-true (match-result-matched? res1))
    (check (match-result-new-offset res1) => 2)
  ) ;let
  (let ((res2 (match-rule r "\\u00P" 0 5 0)))
    (check-true (match-result-matched? res2))
    (check (match-result-new-offset res2) => 4)
  ) ;let
) ;let

;; Hex
(let ((r (make-rule 'hex "BaseN" '(stay) #f)))
  (let ((res1 (match-rule r "0x1f," 0 5 0)))
    (check-true (match-result-matched? res1))
    (check (match-result-new-offset res1) => 4)
  ) ;let
  (let ((res2 (match-rule r "0xFFULL;" 0 8 0)))
    (check-true (match-result-matched? res2))
    (check (match-result-new-offset res2) => 7)
  ) ;let
  (check-false (match-result-matched? (match-rule r "123" 0 3 0)))
  (check-false (match-result-matched? (match-rule r "0" 0 1 0)))
) ;let

;; column 约束：列号不符 -> 不命中
(let ((r (make-rule 'detect-char "Normal" '(stay) #\) #f #f 2)))
  (check-false (match-result-matched? (match-rule r "(a)" 0 3 0)))
  (check-true (match-result-matched? (match-rule r "(a)" 2 3 0)))
) ;let

;; first-non-space 约束：偏移超过首个非空白字符 -> 不命中
(let ((r (make-rule 'string-detect "Region" '(stay) "BEGIN" #f #t)))
  (check-true (match-result-matched? (match-rule r "BEGIN x" 0 7 0)))
  (check-false (match-result-matched? (match-rule r "  x BEGIN" 3 9 2)))
) ;let

(check-report)
