;; %tool-diff
;; (%tool-diff before after [with-text?]) takes UTF-8 strings and returns
;; (diff-text added removed first-changed-line), or #f when the input exceeds
;; a calculation budget. Omitted previews and absent line positions are #f.
;; CRLF is equivalent to LF; a changed final newline changes one logical line.
(import (scheme base)
  (liii check)
  (liii string)
  (liii pi app interactive tool-diff)
) ;import

(check-set-mode! 'report-failed)

(check (%tool-diff "" "") => '(#f 0 0 #f))
(check (%tool-diff "" "甲\n乙\n") => '("@@ -0,0 +1,2 @@\n+甲\n+乙" 2 0 1))
(check (%tool-diff "one\n\n" "") => '("@@ -1,2 +0,0 @@\n-one\n-" 0 2 1))
(check (%tool-diff "one\r\ntwo\r\n" "one\ntwo\n") => '(#f 0 0 #f))
(check (%tool-diff "one\rtwo\r" "one\ntwo\n") => '(#f 0 0 #f))
(check-catch 'type-error (%tool-diff 1 ""))
(check (%tool-diff "a\nb" "x\ny" #t (lambda () #t)) => #f)
(check (%tool-diff "one\n" "one")
  =>
  '("@@ -1,1 +1,1 @@\n-one\n+one\n\\ No newline at end of file" 1 1 1)
) ;check
(check (%tool-diff "a\nx\nx\nb\n" "a\nx\nb\nx\n" #f) => '(#f 1 1 3))
(check (%tool-diff "a\nc\n" "a\nb\nc\n")
  =>
  '("@@ -1,2 +1,3 @@\n a\n+b\n c" 1 0 2)
) ;check
(check (%tool-diff "a\nx\nb\nc\nd\ne\nf\ng\nh\ny\nz\n"
         "a\nX\nb\nc\nd\ne\nf\ng\nh\nY\nz\n"
       ) ;%tool-diff
  =>
  '("@@ -1,5 +1,5 @@\n a\n-x\n+X\n b\n c\n d\n@@ -7,5 +7,5 @@\n f\n g\n h\n-y\n+Y\n z"
    2 2 2)
) ;check

(define (repeat-line line n)
  (apply string-append (make-list n line))
) ;define

;; A disjoint matrix is declined, but identical edges are trimmed first.
(check (%tool-diff (repeat-line "a\n" 1000) (repeat-line "b\n" 1000)) => #f)
(let ((common (repeat-line "a\n" 1000)))
  (check (%tool-diff (string-append common "before\n")
           (string-append common "after\n")
           #f
         ) ;%tool-diff
    =>
    '(#f 1 1 1001)
  ) ;check
) ;let
;; Large output can retain exact counts without creating a huge UI payload.
(check (%tool-diff "" (repeat-line "a\n" 1000)) => '(#f 1000 0 1))
(check (%tool-diff "" (repeat-line "\n" 9000)) => #f)
(check (%tool-diff (make-string 262145 #\a) "") => #f)
(check-report)
