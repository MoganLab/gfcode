;; pi-device-headers
;; 完整 X-Msh-* 设备信息请求头（六元 alist）。
;;
;; 语法
;; ----
;; (pi-device-headers [env] [config-dir]) -> alist?
;;
;; 参数
;; ----
;; env : list? 或 #f
;; 环境变量 alist；#f 时读真实环境变量。
;;
;; config-dir : string? 或 #f
;; 设备 UUID 持久化目录，缺省 ~/.gf/agent。
;;
;; 返回值
;; ----
;; alist?
;; X-Msh-Platform / X-Msh-Version / X-Msh-Device-Name /
;; X-Msh-Device-Model / X-Msh-Os-Version / X-Msh-Device-Id 六个字段，
;; 值均为非空可打印 ASCII 字符串。

(import (scheme base)
  (liii check)
  (liii path)
  (liii string)
  (liii os)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

;; 六个 X-Msh-* 字段齐全，值均为非空 ASCII
(let ((headers (pi-device-headers '(("HOSTNAME" . "test-host"))
                 (path->string (path-join (path-temp-dir) "gf-device-headers-test"))
               ) ;pi-device-headers
      ) ;headers
     ) ;
  (check-true (pair? headers))
  (for-each
    (lambda (name)
      (let ((pair (assoc name headers)))
        (check-true (pair? pair))
        (check-true (string? (cdr pair)))
        (check-true (not (string-null? (cdr pair))))
        (check-true
          (not
            (string-any (lambda (c) (or (char<? c #\space) (char>? c #\~))) (cdr pair))
          ) ;not
        ) ;check-true
      ) ;let
    ) ;lambda
    '("X-Msh-Platform" "X-Msh-Version" "X-Msh-Device-Name"
      "X-Msh-Device-Model" "X-Msh-Os-Version" "X-Msh-Device-Id")
  ) ;for-each
  (check (cdr (assoc "X-Msh-Platform" headers)) => "gfcode")
  (check (cdr (assoc "X-Msh-Device-Name" headers))
    =>
    (string-append "test-host (gfcode/" (os-type) ")")
  ) ;check
) ;let

(check-report)
