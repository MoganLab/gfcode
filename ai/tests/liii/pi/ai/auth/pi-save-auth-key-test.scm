;; pi-save-auth-key
;; 在指定或默认配置目录下保存或增量更新 auth.json 中的服务商 API 密钥凭证。
;;
;; 语法
;; ----
;; (pi-save-auth-key provider key)
;; (pi-save-auth-key provider key opt-config-dir)
;;
;; 参数
;; ----
;; provider : (or string? symbol?)
;; 服务商标识（如 "kimi-coding"、'deepseek 等）。
;;
;; key : string?
;; 服务商 API Key（非空字符串）。
;;
;; opt-config-dir : (or string? path?)
;; 可选，配置目录路径（默认为 ~/.gf/agent）。若目录不存在会自动递归创建。
;;
;; 返回值
;; ----
;; string?
;; 写入的 auth.json 绝对文件路径。

(import (liii check)
  (liii path)
  (liii json)
  (liii list)
  (liii tempfile)
  (liii pi ai config credential)
  (liii pi ai auth)
) ;import

(check-set-mode! 'report-failed)

;; 读取 models/providers.json 白名单为字符串列表；文件缺失返回 #f

(define (read-whitelist dir)
  (let* ((wl (path-join dir "models" "providers.json"))
         (exists (path-exists? wl))
         (data
           (and exists (string->json (path-read-text (path wl))))
         ) ;data
        ) ;
    (and (vector? data) (vector->list data))
  ) ;let*
) ;define

;; 统计 id 在 ids 中出现的次数

(define (count-occurrences ids id)
  (length (filter (lambda (x) (equal? x id)) ids))
) ;define

;; 1. 参数校验
(check-catch 'type-error (pi-save-auth-key 123 "key"))
(check-catch 'type-error (pi-save-auth-key "deepseek" 123))
(check-catch 'value-error (pi-save-auth-key "   " "key"))
(check-catch 'value-error (pi-save-auth-key "deepseek" "   "))

;; 2. 新建 auth.json 并保存凭据，同时写入 providers.json 白名单
(let* ((tmp (make-temp-dir "gf-auth-save-" ""))
       (target (pi-save-auth-key "deepseek" "sk-test-ds-1" tmp))
       (creds (pi-load-auth tmp))
      ) ;
  (check-true (string? target))
  (check-true (path-exists? (path target)))
  (check (length creds) => 1)
  (check (pi-credential-provider (car creds)) => "deepseek")
  (check (pi-credential-key (car creds)) => "sk-test-ds-1")
  ;; 白名单已写入且包含 deepseek
  (let ((wl (read-whitelist tmp)))
    (check-true (and (pair? wl) (member "deepseek" wl) #t))
  ) ;let
  (path-unlink (path target))
  (let ((wl-file (path-join tmp "models" "providers.json")))
    (when (path-exists? wl-file)
      (path-unlink wl-file)
    ) ;when
  ) ;let
  (let ((models-dir (path-join tmp "models")))
    (when (path-exists? models-dir)
      (path-rmdir models-dir)
    ) ;when
  ) ;let
  (path-rmdir tmp)
) ;let*

;; 3. 增量追加第二个服务商，不破坏旧凭证；白名单幂等不覆盖既有 provider
(let* ((tmp (make-temp-dir "gf-auth-save-" ""))
       (target1 (pi-save-auth-key 'deepseek "sk-ds-1" tmp))
       (target2 (pi-save-auth-key "kimi-coding" "sk-kimi-2" tmp))
       (creds (pi-load-auth tmp))
      ) ;
  (check (length creds) => 2)
  (check (pi-resolve-provider-key "deepseek" creds '()) => "sk-ds-1")
  (check (pi-resolve-provider-key "kimi-coding" creds '()) => "sk-kimi-2")
  ;; 白名单同时包含两个 provider，且无重复
  (let ((wl (read-whitelist tmp)))
    (check-true (and (pair? wl) (member "deepseek" wl) #t))
    (check-true (and (member "kimi-coding" wl) #t))
    (check (count-occurrences wl "deepseek") => 1)
    (check (count-occurrences wl "kimi-coding") => 1)
  ) ;let

  ;; 4. 覆盖更新已有服务商凭证
  (pi-save-auth-key "deepseek" "sk-ds-updated" tmp)
  (let ((updated-creds (pi-load-auth tmp)))
    (check (length updated-creds) => 2)
    (check (pi-resolve-provider-key "deepseek" updated-creds '())
      =>
      "sk-ds-updated"
    ) ;check
    (check (pi-resolve-provider-key "kimi-coding" updated-creds '()) => "sk-kimi-2")
  ) ;let
  ;; 4.1 重复登录同一 provider，白名单不出现重复条目
  (let ((wl (read-whitelist tmp)))
    (check-true (and (pair? wl) (member "deepseek" wl) #t))
    (check (count-occurrences wl "deepseek") => 1)
  ) ;let

  (path-unlink (path (path-join tmp "auth.json")))
  (let ((wl-file (path-join tmp "models" "providers.json")))
    (when (path-exists? wl-file)
      (path-unlink wl-file)
    ) ;when
  ) ;let
  (let ((models-dir (path-join tmp "models")))
    (when (path-exists? models-dir)
      (path-rmdir models-dir)
    ) ;when
  ) ;let
  (path-rmdir tmp)
) ;let*

;; 5. 自动递归创建不存在的配置目录（白名单随 auth.json 一同创建）
(let* ((tmp (make-temp-dir "gf-auth-save-nested-" ""))
       (nested-dir (path-join tmp "deep" "config" "dir"))
       (target (pi-save-auth-key "google" "g-key-test" nested-dir))
       (creds (pi-load-auth nested-dir))
      ) ;
  (check (length creds) => 1)
  (check (pi-credential-provider (car creds)) => "google")
  (check (pi-credential-key (car creds)) => "g-key-test")
  ;; 白名单随嵌套目录一同创建并包含 google
  (let ((wl (read-whitelist (path->string nested-dir))))
    (check-true (and (pair? wl) (member "google" wl) #t))
  ) ;let
  (path-unlink (path target))
  (let ((wl-file (path-join nested-dir "models" "providers.json")))
    (when (path-exists? wl-file)
      (path-unlink wl-file)
    ) ;when
  ) ;let
  (path-rmdir (path-join nested-dir "models"))
  (path-rmdir (path-join tmp "deep" "config" "dir"))
  (path-rmdir (path-join tmp "deep" "config"))
  (path-rmdir (path-join tmp "deep"))
  (path-rmdir tmp)
) ;let*

;; 6. 既有白名单不被覆盖：登录新 provider 追加而不丢失既有项
(let* ((tmp (make-temp-dir "gf-auth-save-wl-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
      ) ;
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text (path wl-file) "[\"google\", \"deepseek\"]\n")
  (pi-save-auth-key "kimi-coding" "sk-kimi" tmp)
  (let ((wl (read-whitelist tmp)))
    (check (length wl) => 3)
    (check (list-ref wl 0) => "google")
    (check (list-ref wl 1) => "deepseek")
    (check (list-ref wl 2) => "kimi-coding")
  ) ;let
  (path-unlink (path (path-join tmp "auth.json")))
  (path-unlink (path wl-file))
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

(check-report)
