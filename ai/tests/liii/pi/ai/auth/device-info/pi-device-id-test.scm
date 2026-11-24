;; pi-device-id
;; 设备 UUID 持久化：读 <config-dir>/device_id，缺失则生成并写入。
;;
;; 语法
;; ----
;; (pi-device-id [config-dir]) -> string?
;;
;; 参数
;; ----
;; config-dir : string?
;; 配置目录，缺省 ~/.gf/agent；device_id 文件位于其下。
;;
;; 返回值
;; ----
;; string?
;; UUID 字符串：已有文件直接读取，空白文件视为缺失重新生成。
;; 同一 config-dir 内缓存复用；非 Windows 写入后 chmod 0600。

(import (scheme base)
  (liii check)
  (liii path)
  (liii string)
  (liii os)
  (liii pi ai auth device-info)
) ;import

(check-set-mode! 'report-failed)

(define (make-temp-dir name)
  (let ((dir (path-join (path-temp-dir) name)))
    (path-mkdir dir :parents #t :exist-ok #t)
    (path->string dir)
  ) ;let
) ;define

;; 首次生成并落盘
(let* ((dir (make-temp-dir "gf-device-id-test-1"))
       (id (pi-device-id dir))
       (file (path-join (path dir) "device_id"))
      ) ;
  (check-true (string? id))
  (check-true (> (string-length id) 0))
  (check-true (path-exists? file))
  (check (path-read-text file) => id)
  ;; 再次调用复用同一 id（缓存与文件一致）
  (check (pi-device-id dir) => id)
) ;let*

;; 已有 device_id 文件直接读取（写入前换一个目录规避缓存）
(let* ((dir (make-temp-dir "gf-device-id-test-2"))
       (file (path-join (path dir) "device_id"))
      ) ;
  (path-write-text file "pre-existing-uuid")
  (check (pi-device-id dir) => "pre-existing-uuid")
) ;let*

;; 空白文件视为缺失，重新生成
(let* ((dir (make-temp-dir "gf-device-id-test-3"))
       (file (path-join (path dir) "device_id"))
      ) ;
  (path-write-text file "   ")
  (let ((id (pi-device-id dir)))
    (check-true (not (string=? id "   ")))
    (check (path-read-text file) => id)
  ) ;let
) ;let*

(check-report)
