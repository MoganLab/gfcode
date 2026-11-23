;; pi-resolve-provider-key-oauth
;; 配置解析只读取 OAuth 凭据快照，不联网刷新、不写 auth.json。
;; 过期与 401 的刷新由请求前 request-oauth-key 钩子统一处理。

(import (liii check)
  (liii path)
  (liii tempfile)
  (liii pi ai time)
  (liii pi ai config credential)
  (liii pi ai auth)
) ;import

(check-set-mode! 'report-failed)

;; 未过期：直接返回 access；env API Key 仍优先。
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
  (check (pi-resolve-provider-key "kimi-coding" creds '(("KIMI_API_KEY"
                                                         . "sk-env")) tmp)
    =>
    "sk-env"
  ) ;check
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

;; 已过期：仍返回配置快照中的 access，不在配置阶段刷新或修改文件。
(let* ((tmp (make-temp-dir "gf-resolve-oauth-" ""))
       (_ (pi-save-auth-oauth! "kimi-coding"
            "expired-acc"
            "ref"
            (- (pi-current-time-millis) 1000)
            #f
            tmp
          ) ;pi-save-auth-oauth!
       ) ;_
       (creds (pi-load-auth tmp))
      ) ;
  (check (pi-resolve-provider-key "kimi-coding" creds '() tmp) => "expired-acc")
  (let ((c (car (pi-load-auth tmp))))
    (check (pi-credential-access c) => "expired-acc")
    (check (pi-credential-refresh c) => "ref")
  ) ;let
  (path-unlink (path (path-join tmp "auth.json")))
  (path-rmdir tmp)
) ;let*

(check-report)
