;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; auth.json 的读取与原子写原语（tmp 文件 + rename + chmod 0600），
;; 供 (liii pi ai auth) 的 api_key 与 oauth 两条持久化路径共用。
(define-library (liii pi ai auth storage)
  (import (scheme base)
    (liii string)
    (liii path)
    (liii json)
    (liii list)
    (liii error)
    (liii os)
  ) ;import
  (export pi-auth-read-json pi-auth-dir-path pi-auth-replace-entry
    pi-auth-write-json! pi-auth-normalize-provider pi-auth-normalize-secret
  ) ;export
  (begin

    (define (pi-auth-read-json filepath)
      (and (path-exists? (path filepath))
        (catch #t
          (lambda () (string->json (path-read-text (path filepath))))
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    ;; 配置目录：显式传入优先，缺省 ~/.gf/agent
    (define (pi-auth-dir-path opt-config-dir)
      (path (if (and (pair? opt-config-dir) (car opt-config-dir))
              (car opt-config-dir)
              (path-join (path-home) ".gf" "agent")
            ) ;if
      ) ;path
    ) ;define

    ;; 替换（或追加）某 provider 的 auth.json 条目，其余条目原样保留
    (define (pi-auth-replace-entry alist p-str entry-fields)
      (let ((filtered
              (filter
                (lambda (entry)
                  (not
                    (string=? (if (symbol? (car entry)) (symbol->string (car entry)) (car entry))
                      p-str
                    ) ;string=?
                  ) ;not
                ) ;lambda
                alist
              ) ;filter
            ) ;filtered
           ) ;
        (append filtered (list (cons p-str entry-fields)))
      ) ;let
    ) ;define

    ;; 原子写 auth.json：tmp 文件 + rename + chmod 0600
    (define (pi-auth-write-json! dir-path updated)
      (let* ((auth-file (path-join dir-path "auth.json"))
             (auth-file-str (path->string auth-file))
             (json-str (string-append (json->string updated :indent 2) "\n"))
             (tmp-file (string-append auth-file-str ".tmp"))
            ) ;
        (unless (path-exists? dir-path)
          (path-mkdir dir-path :parents #t :exist-ok #t)
        ) ;unless
        (path-write-text (path tmp-file) json-str)
        (when (path-exists? auth-file)
          (path-unlink auth-file #t)
        ) ;when
        (path-rename (path tmp-file) auth-file)
        (unless (os-windows?)
          (catch #t (lambda () (g_chmod auth-file-str 384)) (lambda args #f))
        ) ;unless
        auth-file-str
      ) ;let*
    ) ;define

    (define (%normalize-non-empty who field value)
      (if (not (string? value))
        (type-error (string-append who ": " field " must be a string"))
        (let ((trimmed (string-trim-both value)))
          (if (string-null? trimmed)
            (value-error (string-append who ": " field " cannot be empty"))
            trimmed
          ) ;if
        ) ;let
      ) ;if
    ) ;define

    (define (pi-auth-normalize-provider who provider)
      (cond
       ((string? provider) (%normalize-non-empty who "provider" provider))
       ((symbol? provider)
        (%normalize-non-empty who "provider" (symbol->string provider))
       ) ;
       (else (type-error (string-append who ": provider must be a string or symbol")))
      ) ;cond
    ) ;define

    (define (pi-auth-normalize-secret who field value)
      (%normalize-non-empty who field value)
    ) ;define

  ) ;begin
) ;define-library