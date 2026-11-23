;; pi-refresh-oauth-key!
;; 触发 OAuth 强制刷新钩子，请求层收到 401 后用其换取新 access token。
;;
;; 语法
;; ----
;; (pi-refresh-oauth-key! config current-key)
;;
;; 参数
;; ----
;; config : alist?
;; 请求配置关联表。
;;
;; current-key : string?
;; 收到 401 时正在使用的（疑似失效的）access token。
;;
;; 返回值
;; ----
;; string?、'unauthorized 或 #f
;; 成功返回新 access token 字符串；refresh 失败（401/403/invalid_grant）
;; 凭据已清除返回 'unauthorized；非 oauth/无凭据/无钩子返回 #f。

(import (liii check) (liii pi ai keyring))

(check-set-mode! 'report-failed)

;; 无钩子：返回 #f（调用方按现状 401 报错）
(check (pi-refresh-oauth-key! (list (cons 'api-key "k")) "k") => #f)

;; 委托 refresh-oauth-key 钩子返回新 access
(let ((seen '()))
  (let ((cfg
          (list (cons 'api-key "old-acc")
            (cons 'refresh-oauth-key
              (lambda (config current-key)
                (set! seen (list current-key))
                "new-acc"
              ) ;lambda
            ) ;cons
          ) ;list
        ) ;cfg
       ) ;
    (check (pi-refresh-oauth-key! cfg "old-acc") => "new-acc")
    (check seen => '("old-acc"))
  ) ;let
) ;let

;; 钩子返回 'unauthorized（refresh 失败，凭据已清除，需重 /login）
(check
  (pi-refresh-oauth-key!
    (list (cons 'refresh-oauth-key (lambda (config current-key) 'unauthorized)))
    "old-acc"
  ) ;pi-refresh-oauth-key!
  =>
  'unauthorized
) ;check

;; 钩子返回 #f（非 oauth/无凭据/不适用）
(check
  (pi-refresh-oauth-key!
    (list (cons 'refresh-oauth-key (lambda (config current-key) #f)))
    "old-acc"
  ) ;pi-refresh-oauth-key!
  =>
  #f
) ;check

(check-report)
