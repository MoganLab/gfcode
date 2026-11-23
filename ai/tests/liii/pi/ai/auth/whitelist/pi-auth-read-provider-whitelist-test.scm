;; pi-auth-read-provider-whitelist
;; 读取 models/providers.json 白名单为字符串列表（兼容顶层 providers.json）。
;;
;; 语法
;; ----
;; (pi-auth-read-provider-whitelist dir-str) -> (or (listof string?) #f)
;;
;; 参数
;; ----
;; dir-str : string? 配置目录路径字符串。
;;
;; 返回值
;; ----
;; #f            文件缺失、非数组或空数组（视为未配置，回退内置全集）。
;; (listof string?) 白名单 id 列表（语法错/非字符串/重复 id 抛错）。

(import (liii check)
  (liii path)
  (liii json)
  (liii tempfile)
  (liii pi ai auth whitelist)
) ;import

(check-set-mode! 'report-failed)

;; 1. 文件缺失返回 #f
(let ((tmp (make-temp-dir "gf-wl-read-" "")))
  (check (pi-auth-read-provider-whitelist tmp) => #f)
  (path-rmdir tmp)
) ;let

;; 2. 读取 models/providers.json 数组
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
      ) ;
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text wl-file "[\"deepseek\",\"kimi-coding\"]")
  (check (pi-auth-read-provider-whitelist tmp) => '("deepseek" "kimi-coding"))
  (path-unlink wl-file)
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 3. 空数组返回 #f
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
      ) ;
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text wl-file "[]")
  (check (pi-auth-read-provider-whitelist tmp) => #f)
  (path-unlink wl-file)
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 4. 兼容顶层 providers.json（无 models/ 子目录）
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (wl-file (path-join tmp "providers.json"))
      ) ;
  (path-write-text wl-file "[\"anthropic\"]")
  (check (pi-auth-read-provider-whitelist tmp) => '("anthropic"))
  (path-unlink wl-file)
  (path-rmdir tmp)
) ;let*

;; 5. models/providers.json 优先于顶层 providers.json
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (models-dir (path-join tmp "models"))
       (wl-file (path-join models-dir "providers.json"))
       (legacy-file (path-join tmp "providers.json"))
      ) ;
  (path-mkdir models-dir :parents #t :exist-ok #t)
  (path-write-text wl-file "[\"google\"]")
  (path-write-text legacy-file "[\"ollama\"]")
  (check (pi-auth-read-provider-whitelist tmp) => '("google"))
  (path-unlink wl-file)
  (path-unlink legacy-file)
  (path-rmdir models-dir)
  (path-rmdir tmp)
) ;let*

;; 6. 非数组顶层抛 value-error
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (wl-file (path-join tmp "providers.json"))
      ) ;
  (path-write-text wl-file "{}")
  (check-catch 'value-error (pi-auth-read-provider-whitelist tmp))
  (path-unlink wl-file)
  (path-rmdir tmp)
) ;let*

;; 7. 元素非字符串抛 type-error
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (wl-file (path-join tmp "providers.json"))
      ) ;
  (path-write-text wl-file "[\"a\", 1]")
  (check-catch 'type-error (pi-auth-read-provider-whitelist tmp))
  (path-unlink wl-file)
  (path-rmdir tmp)
) ;let*

;; 8. 重复 id 抛 value-error
(let* ((tmp (make-temp-dir "gf-wl-read-" ""))
       (wl-file (path-join tmp "providers.json"))
      ) ;
  (path-write-text wl-file "[\"deepseek\",\"deepseek\"]")
  (check-catch 'value-error (pi-auth-read-provider-whitelist tmp))
  (path-unlink wl-file)
  (path-rmdir tmp)
) ;let*

(check-report)
