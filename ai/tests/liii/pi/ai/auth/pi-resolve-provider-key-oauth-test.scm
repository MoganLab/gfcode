;; pi-resolve-provider-key-oauth
;; pi-resolve-provider-key 的 oauth 分支：未过期返回 access、过期透明刷新
;; 落盘、401 清除凭据、env API Key 优先（1402 测试项 2/4/5 的单元化）。
;;
;; 语法
;; ----
;; (pi-resolve-provider-key provider auth-alist)
;; (pi-resolve-provider-key provider auth-alist opt-env opt-config-dir)
;;
;; 参数
;; ----
;; provider : string?
;; 服务商 id（kimi-coding）。
;;
;; auth-alist : list?
;; pi-load-auth 返回的凭据列表。
;;
;; opt-env : list?
;; 自定义环境变量表。
;;
;; opt-config-dir : string?
;; oauth 刷新落盘目录。
;;
;; 返回值
;; ----
;; string? 或 #f
;; 生效 access token / API Key；刷新失败 #f。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii path)
  (liii subprocess)
  (liii tempfile)
  (liii pi ai time)
  (liii pi ai config credential)
  (liii pi ai auth)
) ;import

(check-set-mode! 'report-failed)

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (string-trim-both (substring line 5 (string-length line))))
    #f
  ) ;if
) ;define

(define stub-file
  (if (file-exists? "tests/stub_kimi_oauth_server.py")
    "tests/stub_kimi_oauth_server.py"
    "ai/tests/stub_kimi_oauth_server.py"
  ) ;if
) ;define

;; 1. oauth 未过期：直接返回 access（无网络）
(let* ((tmp (make-temp-dir "gf-resolve-oauth-" ""))
       (_ (pi-save-auth-oauth! "kimi-coding"
            "fresh-acc"
            "ref"
            (+ (pi-current-time-millis) 3600000)
            #f
            tmp
          ) ;pi-save-auth-oauth!
       ) ;_
       (creds (pi-load-auth tmp))
      ) ;
  (check (pi-resolve-provider-key "kimi-coding" creds '() tmp) => "fresh-acc")
  ;; env API Key 优先于 oauth 凭据（测试项 5 回归）
  (check (pi-resolve-provider-key "kimi-coding" creds '(("KIMI_API_KEY"
                                                         . "sk-env")) tmp)
    =>
    "sk-env"
  ) ;check
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

;; 2. oauth 已过期：透明刷新并落盘新 access/refresh/expires（测试项 4）
(let* ((proc (process-spawn (list "python3" stub-file "refresh-ok") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (tmp (make-temp-dir "gf-resolve-oauth-" ""))
       (_ (pi-save-auth-oauth! "kimi-coding"
            "old-acc"
            "stub-refresh-token"
            (- (pi-current-time-millis) 1000)
            host
            tmp
          ) ;pi-save-auth-oauth!
       ) ;_
       (creds (pi-load-auth tmp))
      ) ;
  (check (pi-resolve-provider-key "kimi-coding" creds '() tmp)
    =>
    "stub-access-token-2"
  ) ;check
  ;; 落盘验证：重新加载后 access/refresh 已轮换，region 保留
  (let* ((creds2 (pi-load-auth tmp))
         (c
           (find (lambda (x) (equal? (pi-credential-provider x) "kimi-coding")) creds2)
         ) ;c
        ) ;
    (check (pi-credential-access c) => "stub-access-token-2")
    (check (pi-credential-refresh c) => "stub-refresh-token-2")
    (check (pi-credential-region c) => host)
    (check-true (> (pi-credential-expires c) (pi-current-time-millis)))
    ;; 新凭据未过期：再次解析不触发网络
    (check (pi-resolve-provider-key "kimi-coding" creds2 '() tmp)
      =>
      "stub-access-token-2"
    ) ;check
  ) ;let*
  (process-kill proc)
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

;; 3. 刷新 401 invalid_grant：清除凭据并返回 #f（测试项 4 后半）
(let* ((proc (process-spawn (list "python3" stub-file "refresh-401") :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (host (string-append "http://127.0.0.1:" (number->string port)))
       (tmp (make-temp-dir "gf-resolve-oauth-" ""))
       (_ (pi-save-auth-oauth! "kimi-coding"
            "old-acc"
            "stub-refresh-token"
            (- (pi-current-time-millis) 1000)
            host
            tmp
          ) ;pi-save-auth-oauth!
       ) ;_
       (creds (pi-load-auth tmp))
      ) ;
  (check (pi-resolve-provider-key "kimi-coding" creds '() tmp) => #f)
  ;; 凭据已被清除
  (check (pi-load-auth tmp) => '())
  (process-kill proc)
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

(check-report)
