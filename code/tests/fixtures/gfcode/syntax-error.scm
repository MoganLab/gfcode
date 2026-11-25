;; 故意构造的语法错误 fixture（括号不闭合），不可格式化。
(define-library (gfcode syntax-error)
  (import (scheme base))
  (export extension)
  (begin
    (define (extension api) "broken"
