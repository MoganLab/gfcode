;; pi-auth-write-provider-whitelist!
;; 原子写 models/providers.json 白名单（tmp + rename，自动递归创建父目录）。
;;
;; 语法
;; ----
;; (pi-auth-write-provider-whitelist! dir-str ids)
;;
;; 参数
;; ----
;; dir-str : string?           配置目录路径字符串。
;; ids     : (listof string?)  白名单 id 列表。
;;
;; 返回值
;; ----
;; 无
;; 把 ids 序列化为 json 数组写入 <dir>/models/providers.json；
;; 自动创建 models/ 父目录；落盘过程用 tmp 文件 + rename 保证原子。

(import (liii check)
  (liii path)
  (liii json)
  (liii tempfile)
  (liii pi ai auth whitelist)
) ;import

(check-set-mode! 'report-failed)

;; 1. 自动创建 models/ 目录并写入，内容可回读，无 .tmp 残留
(let* ((tmp (make-temp-dir "gf-wl-write-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
      ) ;
  (pi-auth-write-provider-whitelist! tmp '("deepseek" "kimi-coding"))
  (check-true (path-exists? wl-file))
  (check-false
    (path-exists? (path (string-append (path->string wl-file) ".tmp")))
  ) ;check-false
  (let ((data (string->json (path-read-text wl-file))))
    (check (vector->list data) => '("deepseek" "kimi-coding"))
  ) ;let
  (path-unlink wl-file)
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 2. 覆盖已有白名单
(let* ((tmp (make-temp-dir "gf-wl-write-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
      ) ;
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text wl-file "[\"ollama\"]")
  (pi-auth-write-provider-whitelist! tmp '("google" "anthropic"))
  (let ((data (string->json (path-read-text wl-file))))
    (check (vector->list data) => '("google" "anthropic"))
  ) ;let
  (path-unlink wl-file)
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 3. 空列表写入空数组
(let* ((tmp (make-temp-dir "gf-wl-write-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
      ) ;
  (pi-auth-write-provider-whitelist! tmp '())
  (let ((data (string->json (path-read-text wl-file))))
    (check (vector-length data) => 0)
  ) ;let
  (path-unlink wl-file)
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

(check-report)
