;; 第二个合法扩展，验证批量加载。
(define-library (gfcode valid-pkg)
  (import (scheme base) (liii pi code core extensions))
  (export extension)
  (begin
    (define (extension api)
      (register-flag! api
        (make-extension-flag-def
          :flag        "--pkg-flag"
          :description "Flag registered from valid-pkg"
          :handler     (lambda (val) val)
        ) ;make-extension-flag-def
      ) ;register-flag!
      "pkg-loaded"
    ) ;define
  ) ;begin
) ;define-library
