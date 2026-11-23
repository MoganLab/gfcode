;; pi-auth-save-provider-whitelist!
;; 把 provider id 合并进 models/providers.json 白名单：读现状（缺失回退内置全集）、
;; 不重复追加、原子落盘；失败静默忽略。
;;
;; 语法
;; ----
;; (pi-auth-save-provider-whitelist! dir-str p-str)
;;
;; 参数
;; ----
;; dir-str : string?  配置目录路径字符串。
;; p-str   : string?  待合并的 provider id。
;;
;; 返回值
;; ----
;; #f
;; 合并 p-str 进 <dir>/models/providers.json，不重复、不覆盖既有条目；
;; 文件缺失时以内置全集为基线。全程 catch，失败返回 #f 不抛错。

(import (liii check)
  (liii list)
  (liii path)
  (liii json)
  (liii tempfile)
  (liii pi ai auth whitelist)
) ;import

(check-set-mode! 'report-failed)

;; 读取 models/providers.json 白名单为字符串列表；文件缺失返回 #f

(define (read-wl dir)
  (let* ((wl (path-join dir "models" "providers.json")))
    (and (path-exists? wl)
      (let ((data (string->json (path-read-text wl))))
        (and (vector? data) (vector->list data))
      ) ;let
    ) ;and
  ) ;let*
) ;define

;; 1. 无白名单时回退内置全集，再追加 p-str
(let* ((tmp (make-temp-dir "gf-wl-save-" ""))
       (ret (pi-auth-save-provider-whitelist! tmp "deepseek"))
      ) ;
  (let ((wl (read-wl tmp)))
    (check-true (and (pair? wl) (member "deepseek" wl) #t))
    ;; 回退内置全集后追加，故 deepseek 仅出现一次
    (check
      (length (filter (lambda (x) (equal? x "deepseek")) wl))
      =>
      1
    ) ;check
  ) ;let
  (let ((wl-file (path-join tmp "models" "providers.json")))
    (path-unlink wl-file)
    (path-rmdir (path-join tmp "models"))
  ) ;let
  (path-rmdir tmp)
) ;let*

;; 2. 既有白名单幂等：重复保存同一 provider 不产生重复条目
(let* ((tmp (make-temp-dir "gf-wl-save-" "")) (models-dir (path-join tmp "models")))
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text (path-join models-dir "providers.json") "[\"anthropic\"]")
  (pi-auth-save-provider-whitelist! tmp "deepseek")
  (pi-auth-save-provider-whitelist! tmp "deepseek")
  (let ((wl (read-wl tmp)))
    (check wl => '("anthropic" "deepseek"))
    ;; 二次保存 deepseek 不重复
    (check
      (length (filter (lambda (x) (equal? x "deepseek")) wl))
      =>
      1
    ) ;check
  ) ;let
  (path-unlink (path-join models-dir "providers.json"))
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 3. 既有 provider 不被覆盖
(let* ((tmp (make-temp-dir "gf-wl-save-" "")) (models-dir (path-join tmp "models")))
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text (path-join models-dir "providers.json")
    "[\"kimi-coding\",\"ollama\"]"
  ) ;path-write-text
  (pi-auth-save-provider-whitelist! tmp "deepseek")
  (let ((wl (read-wl tmp)))
    (check-true (and (member "kimi-coding" wl) (member "ollama" wl) (member "deepseek" wl) #t)
    ) ;check-true
  ) ;let
  (path-unlink (path-join models-dir "providers.json"))
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 4. 异常白名单（非法 json）不应抛错：catch 兜底返回 #f，不崩溃
(let* ((tmp (make-temp-dir "gf-wl-save-" "")) (models-dir (path-join tmp "models")))
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text (path-join models-dir "providers.json") "{not-json")
  (check (pi-auth-save-provider-whitelist! tmp "deepseek") => #f)
  ;; 非法文件原样保留，未被覆盖
  (check-true (path-exists? (path-join models-dir "providers.json")))
  (path-unlink (path-join models-dir "providers.json"))
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

(check-report)
