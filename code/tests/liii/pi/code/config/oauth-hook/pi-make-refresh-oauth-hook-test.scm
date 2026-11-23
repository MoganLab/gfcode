;; pi-make-refresh-oauth-hook
;; 构造 401 后强制刷新 oauth 凭据的闭包钩子：按 cfg 当前 provider 现查
;; auth.json，刷新成功落盘返回新 access；invalid_grant 清除凭据返回 #f。
;;
;; 语法
;; ----
;; (pi-make-refresh-oauth-hook captured-env captured-dir) -> procedure?
;;
;; 参数
;; ----
;; captured-env : list?
;; 环境变量 alist（KIMI_CODE_OAUTH_HOST 覆盖）。
;;
;; captured-dir : string?
;; auth.json 所在配置目录（落盘/清除回调使用）。
;;
;; 返回值
;; ----
;; procedure?
;; 钩子 (lambda (cfg current-key) ...)：返回新 access 字符串或 #f。

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii string)
  (liii subprocess)
  (liii pi ai config runtime)
  (liii pi ai auth)
  (liii pi ai time)
  (liii pi code config oauth-hook)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-make-refresh-oauth-hook-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR)
) ;when
(path-mkdir TMP-DIR :parents #t :exist-ok #t)

(define stub-file
  (cond ((file-exists? "code/tests/stub_kimi_oauth_server.py")
         "code/tests/stub_kimi_oauth_server.py"
        ) ;
        ((file-exists? "tests/stub_kimi_oauth_server.py")
         "tests/stub_kimi_oauth_server.py"
        ) ;
        (else "../code/tests/stub_kimi_oauth_server.py")
  ) ;cond
) ;define

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

;; 写 kimi-coding oauth 凭据：region 指向 stub host，expires 仍在未来
;; （401 强制刷新不查 expires）

(define (write-auth! host refresh-token)
  (path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
    (string-append "{\"kimi-coding\":{\"type\":\"oauth\",\"access\":\"old-acc\","
      "\"refresh\":\""
      refresh-token
      "\",\"expires\":"
      (number->string (+ (pi-current-time-millis) 3600000))
      ",\"region\":\""
      host
      "\"}}"
    ) ;string-append
  ) ;path-write-text
) ;define

(define (make-cfg)
  (make-pi-config :config-dir TMP-DIR :provider "kimi-coding")
) ;define

;; 1. refresh 成功：返回新 access，auth.json 落盘新凭据
(let* ((proc (process-spawn (list "python3" stub-file "refresh-ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (write-auth! host "stub-refresh-token")
  (let* ((hook (pi-make-refresh-oauth-hook '() TMP-DIR))
         (next (hook (make-cfg) "old-acc"))
        ) ;
    (check next => "stub-access-token-2")
    (check (length (pi-load-auth TMP-DIR)) => 1)
    (check (pi-resolve-provider-key "kimi-coding" (pi-load-auth TMP-DIR) '() TMP-DIR)
      =>
      "stub-access-token-2"
    ) ;check
  ) ;let*
  (process-kill proc)
) ;let*

;; 2. refresh 失败（401 invalid_grant）：清除凭据返回 #f
(let* ((proc (process-spawn (list "python3" stub-file "refresh-401") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (write-auth! host "stub-refresh-token")
  (let* ((hook (pi-make-refresh-oauth-hook '() TMP-DIR))
         (next (hook (make-cfg) "old-acc"))
        ) ;
    (check next => #f)
    (check (pi-load-auth TMP-DIR) => '())
  ) ;let*
  (process-kill proc)
) ;let*

;; 3. cfg provider 无 oauth 凭据：返回 #f（不动其他 provider 凭据）
(path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
  "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"}}"
) ;path-write-text
(let ((hook (pi-make-refresh-oauth-hook '() TMP-DIR)))
  (check (hook (make-cfg) "old-acc") => #f)
  (check (length (pi-load-auth TMP-DIR)) => 1)
) ;let

(rmtree TMP-DIR)

(check-report)
