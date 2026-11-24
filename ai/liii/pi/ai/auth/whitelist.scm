;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; models/providers.json 白名单的读、写、合并原语（对齐 pi Models 的
;; completeProviderAuthentication：登录后把 provider 合并进白名单，使
;; /model 与 --list-models 即时可见）。保持 ai 层纯净，仅用 ai 层 + 标准
;; 库原语实现，不反向 import code 层（避免循环依赖）。
(define-library (liii pi ai auth whitelist)
  (import (scheme base)
    (liii string)
    (liii path)
    (liii json)
    (liii list)
    (liii error)
    (liii os)
    (liii sort)
    (liii pi ai providers registry)
  ) ;import
  (export pi-auth-builtin-provider-ids pi-auth-merge-provider-id
    pi-auth-read-provider-whitelist pi-auth-write-provider-whitelist!
    pi-auth-save-provider-whitelist!
  ) ;export
  (begin

    ;; 内置 provider id 全集（对齐 %provider-ids 的回退语义）：
    ;; 白名单缺失或空时，全部内置 provider 视为已配置；all-in-one 为伪 provider
    ;; 不计入登录写入（其可见性由子 provider 是否激活决定），故排除。
    (define (pi-auth-builtin-provider-ids)
      (list-sort string<?
        (filter (lambda (p) (not (equal? p "all-in-one")))
          (map car PI_PROVIDER_BUILTIN_MODELS)
        ) ;filter
      ) ;list-sort
    ) ;define

    ;; 不重复追加 p-str 到 ids 列表（保持既有顺序，已存在则原样返回）
    (define (pi-auth-merge-provider-id ids p-str)
      (if (member p-str ids) ids (append ids (list p-str)))
    ) ;define

    ;; 读取 models/providers.json 白名单（纯字符串列表）。
    ;; 文件缺失、非数组或空数组返回 #f（视为未配置，回退内置全集）。
    ;; 语法错、元素非字符串、重复 id 均抛错（与 pi-load-providers-whitelist 一致），
    ;; 由调用方 catch 决定是否中止写入，避免静默覆盖用户手写的异常白名单。
    (define (pi-auth-read-provider-whitelist dir-str)
      (let* ((wl-file (path-join (path dir-str) "models" "providers.json"))
             (legacy (path-join (path dir-str) "providers.json"))
             (path-str (cond ((path-exists? wl-file) (path->string wl-file))
                             ((path-exists? legacy) (path->string legacy))
                             (else #f)
                       ) ;cond
             ) ;path-str
             (data
               (and path-str (string->json (path-read-text (path path-str))))
             ) ;data
            ) ;
        (cond ((not data) #f)
              ((not (vector? data))
               (error 'value-error "models/providers.json: 顶层必须是 json array")
              ) ;
              ((zero? (vector-length data)) #f)
              (else
                (let* ((ids (vector->list data)) (strings (and (every string? ids) ids)))
                  (unless strings
                    (error 'type-error "models/providers.json: 元素必须是字符串")
                  ) ;unless
                  (let loop
                    ((seen '()) (rest strings))
                    (cond ((null? rest) strings)
                          ((member (car rest) seen)
                           (error 'value-error
                             (string-append "models/providers.json: 重复 provider id \"" (car rest) "\"")
                           ) ;error
                          ) ;
                          (else (loop (cons (car rest) seen) (cdr rest)))
                    ) ;cond
                  ) ;let
                ) ;let*
              ) ;else
        ) ;cond
      ) ;let*
    ) ;define

    ;; 原子写 models/providers.json 白名单（tmp + rename，自动递归创建父目录）：
    ;; 复用 auth.json 同样的原子写策略，保证落盘过程不被读到半截 JSON。
    (define (pi-auth-write-provider-whitelist! dir-str ids)
      (let* ((models-dir (path-join (path dir-str) "models"))
             (wl-file (path-join models-dir "providers.json"))
             (wl-str (path->string wl-file))
             (json-str (string-append (json->string (list->vector ids) :indent 2) "\n"))
             (tmp-file (string-append wl-str ".tmp"))
            ) ;
        (unless (path-exists? models-dir)
          (path-mkdir models-dir :parents #t :exist-ok #t)
        ) ;unless
        (path-write-text (path tmp-file) json-str)
        (when (path-exists? wl-file)
          (path-unlink wl-file #t)
        ) ;when
        (path-rename (path tmp-file) wl-file)
      ) ;let*
    ) ;define

    ;; 把 p-str 合并进 models/providers.json 白名单：
    ;; 读现状（缺失回退内置全集）、不重复追加、原子落盘。
    ;; 失败静默忽略（白名单缺失只影响 /model 与 --list-models 可见性，不应使登录失败）。
    (define (pi-auth-save-provider-whitelist! dir-str p-str)
      (catch #t
        (lambda ()
          (let* ((current (or (pi-auth-read-provider-whitelist dir-str) (pi-auth-builtin-provider-ids))
                 ) ;current
                 (merged (pi-auth-merge-provider-id current p-str))
                ) ;
            (pi-auth-write-provider-whitelist! dir-str merged)
          ) ;let*
        ) ;lambda
        (lambda args #f)
      ) ;catch
    ) ;define

  ) ;begin
) ;define-library
