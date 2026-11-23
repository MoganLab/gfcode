;; pi-auth-write-json!
;; 原子写 auth.json：tmp 文件 + rename + chmod 0600，目录自动创建。
;;
;; 语法
;; ----
;; (pi-auth-write-json! dir-path updated) -> string?
;;
;; 参数
;; ----
;; dir-path : path?
;; 配置目录。
;;
;; updated : list?
;; 完整 auth.json alist。
;;
;; 返回值
;; ----
;; string?
;; 写入的 auth.json 路径。

(import (liii check)
  (liii os)
  (liii path)
  (liii path stat)
  (liii json)
  (liii tempfile)
  (liii pi ai auth storage)
) ;import

(check-set-mode! 'report-failed)

;; 1. 自动创建目录并写入，内容可回读，无 .tmp 残留
(let* ((tmp (make-temp-dir "gf-auth-write-" ""))
       (dir (path-join tmp "nested" "cfg"))
       (target
         (pi-auth-write-json! dir '(("kimi-coding" ("type" . "oauth"))))
       ) ;target
      ) ;
  (check-true (path-exists? (path target)))
  (check-false (path-exists? (path (string-append target ".tmp"))))
  (let ((data (string->json (path-read-text (path target)))))
    (check
      (cdr (assoc "type" (cdr (assoc "kimi-coding" data))))
      =>
      "oauth"
    ) ;check
  ) ;let
  (unless (os-windows?)
    (check (logand (path-stat-mode (path-stat target)) 511) => 384)
  ) ;unless
  (path-unlink (path target))
  (path-rmdir dir)
  (path-rmdir (path-join tmp "nested"))
  (path-rmdir tmp)
) ;let*

;; 2. 覆盖已有文件
(let* ((tmp (make-temp-dir "gf-auth-write-" ""))
       (target
         (pi-auth-write-json! (path tmp) '(("a" ("key" . "1"))))
       ) ;target
      ) ;
  (pi-auth-write-json! (path tmp) '(("b" ("key" . "2"))))
  (let ((data (string->json (path-read-text (path target)))))
    (check (assoc "a" data) => #f)
    (check
      (cdr (assoc "key" (cdr (assoc "b" data))))
      =>
      "2"
    ) ;check
  ) ;let
  (path-unlink (path target))
  (path-rmdir tmp)
) ;let*

(check-report)
