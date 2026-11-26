;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode web-search schema)
  (import (scheme base) (liii error) (liii string) (liii pi code core tools read))
  (export pi-web-search-schema
    pi-validate-web-search-args
    pi-normalize-web-search-urls
  ) ;export
  (begin

    (define (%web-search-prop type desc)
      (list (cons "type" type) (cons "description" desc))
    ) ;define

    (define (pi-web-search-schema)
      (list (cons "type" "object")
        (cons "properties"
          (list (cons "query"
                  (%web-search-prop "string" "The search query or question to answer")
                ) ;cons
            (cons "urls"
              (append (%web-search-prop "array"
                        "Additional URLs to analyze along with search (up to 20)"
                      ) ;%web-search-prop
                (list (cons "items" (list (cons "type" "string"))) (cons "maxItems" 20))
              ) ;append
            ) ;cons
          ) ;list
        ) ;cons
        (cons "required" #("query"))
      ) ;list
    ) ;define

    ;; string->json 把 JSON 数组解析为 vector，而手写 alist 参数常用 list；
    ;; 两种表示都合法，统一规范化为 list，避免间歇性的 urls 类型错误。
    (define (pi-normalize-web-search-urls urls)
      (cond ((vector? urls) (vector->list urls))
            ((list? urls) urls)
            (else urls)
      ) ;cond
    ) ;define

    (define (%all-strings? items)
      (cond ((null? items) #t)
            ((string? (car items)) (%all-strings? (cdr items)))
            (else #f)
      ) ;cond
    ) ;define

    (define (pi-validate-web-search-args args)
      (let ((query (pi-arg-ref args "query" #f))
            (urls (pi-normalize-web-search-urls (pi-arg-ref args "urls" #f)))
           ) ;
        (cond ((not (string? query)) (type-error "web_search: query must be a string"))
              ((string-null? (string-trim-both query))
               (value-error "web_search: query must not be empty")
              ) ;
              ((eq? urls #f) #t)
              ((not (list? urls)) (type-error "web_search: urls must be a list of strings"))
              ((not (%all-strings? urls))
               (type-error "web_search: every urls entry must be a string")
              ) ;
              ((> (length urls) 20)
               (value-error "web_search: urls must contain at most 20 entries")
              ) ;
              (else #t)
        ) ;cond
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
