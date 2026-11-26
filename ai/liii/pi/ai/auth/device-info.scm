;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; Kimi Coding 设备信息请求头（对齐 Kimi CLI 的 createKimiDeviceHeaders）。
;;
;; Kimi 服务端依据 X-Msh-Device-Name 在账号中心"登录设备"列表展示设备名；
;; 缺失时显示"未知设备"。gfcode 在主机名后追加 (gfcode/<os-type>) 后缀，
;; 便于区分同一账号下不同操作系统、不同客户端的登录记录。
;;
;; X-Msh-Device-Id 持久化在 ~/.gf/agent/device_id（首次随机 UUID，之后复用），
;; 与 Kimi CLI 的 ~/.kimi-code/device_id 同构；读写失败静默降级，不影响登录。
(define-library (liii pi ai auth device-info)
  (import (scheme base)
    (scheme process-context)
    (scheme char)
    (liii list)
    (liii string)
    (liii os)
    (liii path)
    (liii uuid)
    (liii subprocess)
  ) ;import
  (export pi-device-headers
    pi-device-id
    PI_DEVICE_PLATFORM
    PI_DEVICE_VERSION
    ;; 纯函数与内部助手导出，供单测直接覆盖
    %pi-ascii-header
    %pi-device-name
    %pi-device-model
    %pi-os-version
  ) ;export
  (begin

    (define PI_DEVICE_PLATFORM "gfcode")
    ;; 与 gfproject.json package.version 同步，发版时一并更新
    (define PI_DEVICE_VERSION "2026.11.24")

    ;; HTTP header 值仅允许可打印 ASCII（0x20-0x7E）：其余字符剔除后 trim，
    ;; 结果为空时回退 fallback（对齐 Kimi CLI asciiHeader）
    (define* (%pi-ascii-header value (fallback "unknown"))
      (if (not (string? value))
        fallback
        (let ((cleaned
                (string-trim-both
                  (list->string
                    (filter
                      (lambda (c) (and (char>=? c #\space) (char<=? c #\~)))
                      (string->list value)
                    ) ;filter
                  ) ;list->string
                ) ;string-trim-both
              ) ;cleaned
         ) ;
          (if (string-null? cleaned) fallback cleaned)
        ) ;let
      ) ;if
    ) ;define*

    ;; env 为 #f 时读真实环境变量；为 alist 时仅查表（单测注入）
    (define (%env name env)
      (if env
        (let ((pair (assoc name env)))
          (and pair (cdr pair))
        ) ;let
        (get-environment-variable name)
      ) ;if
    ) ;define

    (define (%non-empty v)
      (and (string? v) (not (string-null? (string-trim-both v))) v)
    ) ;define

    ;; 执行命令取首行 stdout；任何失败（命令不存在、非零退出等）归一为 #f
    (define (%command-first-line cmd args)
      (catch #t
        (lambda ()
          (let ((proc (process-spawn (cons cmd args) :stdout 'pipe :stderr 'discard)))
            (let ((line (process-read-line proc)))
              (process-wait proc 2000)
              (%non-empty (and (string? line) (string-trim-both line)))
            ) ;let
          ) ;let
        ) ;lambda
        (lambda args #f)
      ) ;catch
    ) ;define

    ;; 主机名：COMPUTERNAME（Windows）> HOSTNAME > hostname 命令 > "unknown"
    (define (%raw-hostname env)
      (or (%non-empty (%env "COMPUTERNAME" env))
        (%non-empty (%env "HOSTNAME" env))
        (%command-first-line "hostname" '())
        "unknown"
      ) ;or
    ) ;define

    ;; 设备名：<hostname> (gfcode/<os-type>)，整体 ASCII 清洗
    (define (%pi-device-name env)
      (%pi-ascii-header
        (string-append (%raw-hostname env) " (gfcode/" (os-type) ")")
      ) ;%pi-ascii-header
    ) ;define

    ;; 设备型号：<os-type> <os-arch>，如 "Windows x64" / "Darwin arm64"
    (define (%pi-device-model)
      (%pi-ascii-header (string-append (os-type) " " (os-arch)))
    ) ;define

    ;; 系统版本：Windows 取 OS 环境变量，其余取 uname -sr，兜底 os-type
    (define (%pi-os-version env)
      (%pi-ascii-header
        (or (and (os-windows?) (%non-empty (%env "OS" env)))
          (and (not (os-windows?)) (%command-first-line "uname" '("-sr")))
          (os-type)
        ) ;or
      ) ;%pi-ascii-header
    ) ;define

    (define *device-id-cache* #f)
    ;; 缓存的 config-dir：切换目录（单测注入）时重新读取而非复用缓存
    (define *device-id-cache-dir* #f)

    (define (%read-device-id file)
      (and (path-exists? file)
        (catch #t
          (lambda () (%non-empty (string-trim-both (path-read-text file))))
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    ;; 设备 UUID：读 <config-dir>/device_id（默认 ~/.gf/agent），缺失则生成
    ;; uuid4 并持久化（非 Windows chmod 0600）；写失败仅影响持久化，不影响返回
    (define (pi-device-id . opt-config-dir)
      (let ((dir-str (if (and (pair? opt-config-dir) (car opt-config-dir))
                       (car opt-config-dir)
                       #f
                     ) ;if
            ) ;dir-str
           ) ;
        (or (and *device-id-cache* (equal? *device-id-cache-dir* dir-str) *device-id-cache*)
          (let* ((dir (path (if dir-str
                              dir-str
                              (path-join (path-home) ".gf" "agent")
                            ) ;if
                      ) ;path
                 ) ;dir
                 (file (path-join dir "device_id"))
                 (existing (%read-device-id file))
                 (id (or existing (string-downcase (uuid4))))
                ) ;
            (unless existing
              (catch #t
                (lambda ()
                  (unless (path-exists? dir)
                    (path-mkdir dir :parents #t :exist-ok #t)
                  ) ;unless
                  (path-write-text file id)
                  (unless (os-windows?)
                    (catch #t
                      (lambda () (g_chmod (path->string file) 384))
                      (lambda args #f)
                    ) ;catch
                  ) ;unless
                ) ;lambda
                (lambda args #f)
              ) ;catch
            ) ;unless
            (set! *device-id-cache* id)
            (set! *device-id-cache-dir* dir-str)
            id
          ) ;let*
        ) ;or
      ) ;let
    ) ;define

    ;; 完整 X-Msh-* 请求头（alist），附加到 OAuth 各端点请求上。
    ;; env/config-dir 仅单测注入；默认读真实环境与 ~/.gf/agent。
    (define* (pi-device-headers (env #f) (config-dir #f))
      (list (cons "X-Msh-Platform" PI_DEVICE_PLATFORM)
        (cons "X-Msh-Version" PI_DEVICE_VERSION)
        (cons "X-Msh-Device-Name" (%pi-device-name env))
        (cons "X-Msh-Device-Model" (%pi-device-model))
        (cons "X-Msh-Os-Version" (%pi-os-version env))
        (cons "X-Msh-Device-Id"
          (if config-dir (pi-device-id config-dir) (pi-device-id))
        ) ;cons
      ) ;list
    ) ;define*

  ) ;begin
) ;define-library
