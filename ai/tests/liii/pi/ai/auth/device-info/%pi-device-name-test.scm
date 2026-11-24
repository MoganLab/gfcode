;; %pi-device-name
;; 设备名组装：<hostname> (gfcode/<os-type>)，整体 ASCII 清洗。
;;
;; 语法
;; ----
;; (%pi-device-name env) -> string?
;;
;; 参数
;; ----
;; env : list? 或 #f
;; 环境变量 alist；#f 时读真实环境变量。
;; COMPUTERNAME（Windows）> HOSTNAME > hostname 命令 > "unknown"。
;;
;; 返回值
;; ----
;; string?
;; 带 gfcode/<os-type> 后缀的设备名，仅含可打印 ASCII。

(import (scheme base)
  (liii check)
  (liii os)
  (liii string)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

;; COMPUTERNAME 优先，带 gfcode/<os-type> 后缀
(check (%pi-device-name '(("COMPUTERNAME" . "DESKTOP-A") ("HOSTNAME" . "ignored")))
  =>
  (string-append "DESKTOP-A (gfcode/" (os-type) ")")
) ;check

;; HOSTNAME 兜底
(check (%pi-device-name '(("HOSTNAME" . "linux-box")))
  =>
  (string-append "linux-box (gfcode/" (os-type) ")")
) ;check

;; 非 ASCII 主机名清洗后仍带后缀（清洗发生在后缀拼接之后）
(check (%pi-device-name '(("HOSTNAME" . "开发机")))
  =>
  (string-append "(gfcode/" (os-type) ")")
) ;check

;; 空白 COMPUTERNAME 视为未设置，回退 HOSTNAME
(check (%pi-device-name '(("COMPUTERNAME" . "  ") ("HOSTNAME" . "fallback-host")))
  =>
  (string-append "fallback-host (gfcode/" (os-type) ")")
) ;check

(check-report)
