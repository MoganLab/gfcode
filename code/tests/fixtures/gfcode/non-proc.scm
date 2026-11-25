;; 未导出 extension 的非法扩展。
(define-library (gfcode non-proc)
  (import (scheme base))
  (export not-a-procedure)
  (begin
    (define not-a-procedure "not-a-procedure")
  ) ;begin
) ;define-library
