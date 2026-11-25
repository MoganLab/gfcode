;; 合法的单文件 library 扩展。
(define-library (gfcode valid-ext1)
  (import (scheme base) (liii pi code core extensions))
  (export extension)
  (begin
    (define (extension api)
      (register-tool! api
        (make-extension-tool-def
          :name        "test-tool-1"
          :description "Tool 1 from valid-ext1"
          :execute     (lambda (args) "result-1")
        ) ;make-extension-tool-def
      ) ;register-tool!
      "ext1-loaded"
    ) ;define
  ) ;begin
) ;define-library
