;; pi-cfg-api-key-set!
;; OAuth 刷新成功后，原地同步短期 access token 到当前请求配置。
;;
;; 语法
;; ----
;; (pi-cfg-api-key-set! cfg api-key) -> string?
;;
;; 参数
;; ----
;; cfg : <pi-config> | alist
;; 当前请求及其后续请求共享的配置；alist 必须已有 api-key 条目。
;;
;; api-key : any
;; 刷新后的 access token。
;;
;; 返回值
;; ------
;; 返回 api-key；原配置对象被更新，对象身份保持不变。

(import (liii check) (liii pi ai config runtime))

(check-set-mode! 'report-failed)

(let ((cfg (make-pi-config :api-key "old-access")))
  (check (pi-cfg-api-key-set! cfg "new-access") => "new-access")
  (check (pi-cfg-ref cfg 'api-key) => "new-access")
) ;let

(let ((cfg (list (cons 'provider "kimi-coding") (cons 'api-key "old-access"))))
  (pi-cfg-api-key-set! cfg "new-access")
  (check (pi-cfg-ref cfg 'api-key) => "new-access")
  (check (length cfg) => 2)
) ;let

(check-catch 'pi-config-error (pi-cfg-api-key-set! '() "new-access"))
(check-catch 'pi-config-error
  (pi-cfg-api-key-set! '((provider . "kimi-coding")) "new-access")
) ;check-catch

(check-report)
