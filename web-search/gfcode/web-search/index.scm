;;
;; Ported from pi-web-search (https://github.com/ttttmr/pi-web-search)
;; Original work Copyright (c) 2026 ttttmr
;; Goldfish Scheme port Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode web-search index)
  (import (scheme base)
    (liii pi code core extensions)
    (gfcode web-search schema)
    (gfcode web-search execute)
  ) ;import
  (export extension)
  (begin

    ;; web-search 扩展：注册 web_search 工具并声明默认启用（:default-active? #t，
    ;; 由 resolve-active-tools 并入默认集）；实现位于 (gfcode web-search ...) 子库。

    (define (extension api . opt-context)
      (register-tool! api
        (make-extension-tool-def "web_search"
          "Search the web using Gemini Google Search grounding."
          (pi-web-search-schema)
          pi-execute-web-search
          :snippet "Search the web for up-to-date information"
          :guidelines
          '("Use web_search when you need real-time information or external references.")
          :default-active? #t
        ) ;make-extension-tool-def
      ) ;register-tool!
      "web-search-loaded"
    ) ;define

  ) ;begin
) ;define-library
