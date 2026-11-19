;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 模型目录 headers 解析：${API_KEY} 保留至请求时展开，环境变量在配置阶段插值。
(define-library (liii pi code config headers)
  (import (scheme base)
    (liii base)
    (liii list)
    (liii string)
    (liii pi ai template)
    (liii pi ai models catalog)
    (liii pi code config settings)
  ) ;import
  (export %resolve-header-value pi-resolve-request-headers)
  (begin

    ;; 将模型目录的 headers 对象转换为请求层使用的 header alist。
    ;; ${API_KEY} 保留至每次请求时按当前 key 展开，支持密钥轮换；环境变量在此解析。
    (define (%resolve-header-value name value api-key opt-env provider model-id)
      (unless (string? value)
        (error 'pi-config-error
          (string-append "Header \"" name "\" for model \"" provider "/" model-id
            "\" must have a string value"
          ) ;string-append
        ) ;error
      ) ;unless
      (let* ((key-required? (string-contains? value "${API_KEY}"))
             (_
               (when (and key-required?
                       (or (not (string? api-key)) (string-null? api-key))
                     ) ;and
                 (error 'pi-config-error
                   (string-append "Header \"" name "\" for model \"" provider "/" model-id
                     "\" requires ${API_KEY}, but no API key was resolved"
                   ) ;string-append
                 ) ;error
               ) ;when
             ) ;_
             (template (string-replace value "${API_KEY}" "$${API_KEY}"))
             (resolved (if (pair? opt-env)
                         (pi-resolve-config-value template (car opt-env))
                         (pi-resolve-config-value template)
                       ) ;if
             ) ;resolved
            ) ;
        (unless (string? resolved)
          (error 'pi-config-error
            (string-append "Header \"" name "\" for model \"" provider "/" model-id
              "\" references an undefined environment variable"
            ) ;string-append
          ) ;error
        ) ;unless
        resolved
      ) ;let*
    ) ;define

    (define* (pi-resolve-request-headers models-store provider model-id api-key . opt-env)
      (let* ((model
               (find (lambda (entry) (equal? (json-dict-ref entry "id" #f) model-id))
                 (pi-catalog-provider-models models-store provider)
               ) ;find
             ) ;model
             (headers (and model (json-dict-ref model "headers" '())))
            ) ;
        (cond ((not headers) '())
              ((not (list? headers))
               (error 'pi-config-error
                 (string-append "Headers for model \"" provider "/" model-id
                   "\" must be a JSON object"
                 ) ;string-append
               ) ;error
              ) ;not
              (else
                (map
                  (lambda (h)
                    (unless (and (pair? h) (string? (car h)) (not (string-null? (car h))))
                      (error 'pi-config-error
                        (string-append "Headers for model \"" provider "/" model-id
                          "\" must have non-empty string names"
                        ) ;string-append
                      ) ;error
                    ) ;unless
                    (cons (car h)
                      (%resolve-header-value (car h) (cdr h) api-key opt-env provider model-id)
                    ) ;cons
                  ) ;lambda
                  headers
                ) ;map
              ) ;else
        ) ;cond
      ) ;let*
    ) ;define*

  ) ;begin
) ;define-library
