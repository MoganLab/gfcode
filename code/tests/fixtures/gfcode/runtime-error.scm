;; 工厂执行时抛出错误的扩展。
(define-library (gfcode runtime-error)
  (import (scheme base))
  (export extension)
  (begin
    (define (extension api)
      (error 'extension-runtime-error "Deliberate error during extension execution")
    ) ;define
  ) ;begin
) ;define-library
