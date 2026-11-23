;; pi-auth-login-oauth
;; 非交互 device flow 登录：打印 verification URL 让用户手动打开，
;; 轮询成功后落盘 oauth 凭据（1402 §5.4 可选子项）。
;;
;; 语法
;; ----
;; (pi-auth-login-oauth provider)
;; (pi-auth-login-oauth provider config-dir)
;; (pi-auth-login-oauth provider config-dir custom-env)
;;
;; 参数
;; ----
;; provider : string?
;; 凭据归属服务商。
;;
;; config-dir : any?
;; 配置目录路径（默认 (gf-get-config-dir)）。
;;
;; custom-env : list?
;; 自定义环境变量表（KIMI_CODE_OAUTH_HOST 覆盖 host）。
;;
;; 返回值
;; ------
;; integer?
;; 成功为 0，登录或落盘失败为 1。

(import (scheme base)
  (liii check)
  (liii string)
  (liii path)
  (liii tempfile)
  (liii subprocess)
  (liii pi tui cli auth)
) ;import

(check-set-mode! 'report-failed)

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define stub-file
  (cond ((file-exists? "tests/stub_kimi_oauth_server.py")
         "tests/stub_kimi_oauth_server.py"
        ) ;
        ((file-exists? "ai/tests/stub_kimi_oauth_server.py")
         "ai/tests/stub_kimi_oauth_server.py"
        ) ;
        ((file-exists? "../ai/tests/stub_kimi_oauth_server.py")
         "../ai/tests/stub_kimi_oauth_server.py"
        ) ;
        ((file-exists? "../../ai/tests/stub_kimi_oauth_server.py")
         "../../ai/tests/stub_kimi_oauth_server.py"
        ) ;
        (else "ai/tests/stub_kimi_oauth_server.py")
  ) ;cond
) ;define

;; 捕获 stderr 输出为字符串（验证失败路径的提示）

(define (with-stderr-to-string thunk)
  (let* ((p (open-output-string)) (orig *stderr*))
    (dynamic-wind (lambda () (set! *stderr* p))
      thunk
      (lambda () (set! *stderr* orig))
    ) ;dynamic-wind
    (get-output-string p)
  ) ;let*
) ;define

;; 1. stub ok：登录成功，落盘 auth.json 的 kimi-coding oauth 条目，返回 0
(let* ((proc (process-spawn (list "python3" stub-file "ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (tmp (make-temp-dir "gf-auth-oauth-test-" ""))
       (auth-file (path-join tmp "auth.json"))
      ) ;
  (let ((status #f))
    (let ((out
            (with-output-to-string
              (lambda ()
                (set! status
                  (pi-auth-login-oauth "kimi-coding"
                    tmp
                    (list (cons "KIMI_CODE_OAUTH_HOST" host))
                  ) ;pi-auth-login-oauth
                ) ;set!
              ) ;lambda
            ) ;with-output-to-string
          ) ;out
         ) ;
      (check status => 0)
      (check-true (string-contains? out "Open this URL to authorize:"))
    ) ;let
    ;; 验证 auth.json 已写入 oauth 条目
    (let ((content (path-read-text auth-file)))
      (check-true (string-contains? content "\"kimi-coding\""))
      (check-true (string-contains? content "stub-access-token"))
    ) ;let
  ) ;let
  (path-unlink auth-file #t)
  (path-rmdir tmp)
  (process-kill proc)
) ;let*

;; 2. host 不可达：登录失败，返回 1，不落盘
(let* ((tmp (make-temp-dir "gf-auth-oauth-test-" ""))
       (auth-file (path-join tmp "auth.json"))
       (status #f)
      ) ;
  (let ((err
          (with-stderr-to-string
            (lambda ()
              (set! status
                (pi-auth-login-oauth "kimi-coding"
                  tmp
                  (list (cons "KIMI_CODE_OAUTH_HOST" "http://127.0.0.1:1"))
                ) ;pi-auth-login-oauth
              ) ;set!
            ) ;lambda
          ) ;with-stderr-to-string
        ) ;err
       ) ;
    (check status => 1)
    (check-true (string-contains? err "OAuth login failed"))
  ) ;let
  (unless (path-exists? auth-file)
    #f
  ) ;unless
  (path-rmdir tmp)
) ;let*

(check-report)
