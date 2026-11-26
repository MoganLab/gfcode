;; (%make-diff-parser loader parse) returns a worker-local raw string -> lines
;; 语法: (%make-diff-parser loader parse)
;; 参数: 无参定义加载器与接受文本、定义的解析过程。
;; 返回值: 字符串到结构化行的过程；失败返回 #f。
;; Worker-local procedure. Failed definitions and over-budget input return #f without parsing.
(import (scheme base)
  (liii check)
  (only (liii base) byte-vector->string)
  (liii highlight definition)
  (liii highlight highlighter)
  (liii pi app interactive views syntax)
) ;import
(check-set-mode! 'report-failed)

(define loads 0)

(define parses 0)

(define (loader)
  (set! loads (+ 1 loads))
  (load-syntax-definition "diff")
) ;define

(define (parser text def)
  (set! parses (+ 1 parses))
  (highlight-text text def)
) ;define

(define parse (%make-diff-parser loader parser))
(check (parse "+中\t\x1b;[31mX\r\n-😀\n ctx\n---\n+++\n@@\n")
  =>
  '(("+中   X" (0 8 "Added"))
    ("-😀" (0 5 "Removed"))
    (" ctx" (0 4 "Normal"))
    ("---" (0 3 "File"))
    ("+++" (0 3 "Header"))
    ("@@" (0 2 "Header")))
) ;check
(check (parse "+x") => '(("+x" (0 2 "Added"))))
(check (parse (make-string 65537 #\x)) => #f)
(check (parse (string-append (make-string 8192 #\newline) "x")) => #f)
(check
  (parse
    (apply string-append (make-list 9 (string-append (make-string 65535 #\x) "\n")))
  ) ;parse
  =>
  #f
) ;check
(check loads => 1)
(check parses => 2)
(let ((bad
        (%make-diff-parser (lambda () (set! loads (+ 1 loads)) (error "missing"))
          parser
        ) ;%make-diff-parser
      ) ;bad
     ) ;
  (check (bad "+x") => #f)
  (check (bad "-x") => #f)
  (check loads => 2)
) ;let
(check
  (parse (string-append "+\x1b;c\x1b;[2K\x1b;]0;test\x07;\x01;"
           (byte-vector->string (make-bytevector 1 255))
           "é"
         ) ;string-append
  ) ;parse
  =>
  '(("+�é" (0 7 "Added")))
) ;check
(check
 ((%make-diff-parser loader (lambda args (error "parse failed"))) "+fail")
 =>
 #f
) ;check

(check-report)
