;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi code modes verbose common)
  (import (scheme base) (liii string) (liii pi ai message))
  (export %substring-index %prop-ref %normalize-message %prop-string
    %prop-boolean
  ) ;export
  (begin

    (define (%substring-index pattern str)
      (let ((plen (string-length pattern)) (slen (string-length str)))
        (let loop
          ((i 0))
          (cond ((> (+ i plen) slen) #f)
                ((string=? (substring str i (+ i plen)) pattern) i)
                (else (loop (+ i 1)))
          ) ;cond
        ) ;let
      ) ;let
    ) ;define

    (define (%prop-ref obj key-sym key-str default)
      (if (not (pair? obj))
        default
        (let ((p (or (assoc key-str obj) (assoc key-sym obj))))
          (if p (cdr p) default)
        ) ;let
      ) ;if
    ) ;define

    ;; 把事件里的 message 字段归一化为 alist：emit 传入的可能是
    ;; <pi-assistant-message>/<pi-user-message> record（JSON 序列化路径
    ;; 由 %normalize-json-value 处理，本模块需自行转换）。
    (define (%normalize-message msg)
      (cond ((pi-message? msg) (pi-message->json msg))
            ((pair? msg) msg)
            (else '())
      ) ;cond
    ) ;define

    (define (%prop-string obj key-sym key-str default)
      (let ((v (%prop-ref obj key-sym key-str default)))
        (if (string? v) v default)
      ) ;let
    ) ;define

    (define (%prop-boolean obj key-sym key-str default)
      (let ((v (%prop-ref obj key-sym key-str default)))
        (cond ((boolean? v) v)
              ((or (eq? v 'true) (equal? v "true")) #t)
              ((or (eq? v 'false) (equal? v "false")) #f)
              (else default)
        ) ;cond
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
