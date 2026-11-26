;; %kimi-post-form 设备信息头端到端验证
;; OAuth 请求（device_authorization）携带 X-Msh-* 设备信息头，stub 回显校验。
;;
;; 语法
;; ----
;; (%kimi-post-form url fields [headers]) -> response-alist?
;;
;; 参数
;; ----
;; url : string?
;; 完整端点 URL（本测试指向本地 stub）。
;;
;; fields : alist?
;; 表单字段。
;;
;; headers : alist? 或 #f
;; 额外请求头；#f 时自动附加完整 X-Msh-* 设备信息头。
;;
;; 返回值
;; ----
;; alist?
;; status-code / text 等；本测试关心 stub 回显的设备头字段。

(import (scheme base)
  (liii check)
  (liii string)
  (liii json)
  (liii os)
  (liii subprocess)
  (liii pi ai auth oauth kimi-coding-oauth)
) ;import

(check-set-mode! 'report-failed)

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define (find-stub)
  (let loop
    ((candidates '("tests/stub_kimi_oauth_server.py"
                   "ai/tests/stub_kimi_oauth_server.py"
                   "stub_kimi_oauth_server.py")
     ) ;candidates
    ) ;
    (cond ((null? candidates)
           (error 'file-not-found "stub_kimi_oauth_server.py not found")
          ) ;
          ((file-exists? (car candidates)) (car candidates))
          (else (loop (cdr candidates)))
    ) ;cond
  ) ;let
) ;define

(let* ((proc (process-spawn (list "python3" (find-stub) "headers") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (resp (%kimi-post-form (string-append host "/api/oauth/device_authorization")
               (list (cons "client_id" "17e5f671-d194-4dfb-9706-5516cb48c098"))
             ) ;%kimi-post-form
       ) ;resp
       (body (resp 'text))
       (json (string->json body))
      ) ;
  (check (resp 'status-code) => 200)
  ;; 平台标识与版本
  (check (json-ref-string json "platform" #f) => "gfcode")
  (check-true (string? (json-ref-string json "version" #f)))
  ;; 设备名：非空、带 gfcode/<os-type> 后缀、纯 ASCII
  (let ((name (json-ref-string json "device_name" #f)))
    (check-true (string? name))
    (check-true (not (string-null? name)))
    (check-true
      (string-contains name (string-append "(gfcode/" (os-type) ")"))
    ) ;check-true
    (check-true
      (not (string-any (lambda (c) (or (char<? c #\space) (char>? c #\~))) name))
    ) ;check-true
  ) ;let
  ;; 设备型号：<os-type> <os-arch>
  (check (json-ref-string json "device_model" #f)
    =>
    (string-append (os-type) " " (os-arch))
  ) ;check
  ;; 系统版本与持久化设备 UUID 均非空
  (check-true (not (string-null? (json-ref-string json "os_version" #f))))
  (check-true (> (string-length (json-ref-string json "device_id" #f)) 0))
  (process-kill proc)
) ;let*

(check-report)
