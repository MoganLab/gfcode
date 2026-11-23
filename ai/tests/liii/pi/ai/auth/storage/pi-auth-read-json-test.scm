;; pi-auth-read-json
;; 读取 JSON 文件为 Scheme 数据；文件缺失或解析失败返回 #f。
;;
;; 语法
;; ----
;; (pi-auth-read-json filepath) -> any
;;
;; 参数
;; ----
;; filepath : string?
;; JSON 文件路径。
;;
;; 返回值
;; ----
;; any
;; 解析后的 JSON 数据（alist/vector/标量）；缺失或非法返回 #f。

(import (liii check) (liii path) (liii tempfile) (liii pi ai auth storage))

(check-set-mode! 'report-failed)

;; 缺失文件
(check (pi-auth-read-json "/nonexistent/gf-auth-read-test.json") => #f)

;; 正常读取
(let* ((tmp (make-temp-dir "gf-auth-read-" "")) (f (path-join tmp "a.json")))
  (path-write-text f "{\"kimi-coding\":{\"type\":\"oauth\",\"expires\":123}}")
  (let ((data (pi-auth-read-json (path->string f))))
    (check
      (cdr (assoc "type" (cdr (assoc "kimi-coding" data))))
      =>
      "oauth"
    ) ;check
    (check
      (cdr (assoc "expires" (cdr (assoc "kimi-coding" data))))
      =>
      123
    ) ;check
  ) ;let
  ;; 非法 JSON
  (path-write-text f "{invalid")
  (check (pi-auth-read-json (path->string f)) => #f)
  (path-unlink f)
  (path-rmdir tmp)
) ;let*

(check-report)
