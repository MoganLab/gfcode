;; pi-oauth-refresh-enabled?
;; 判断当前配置是否启用了 401 后 OAuth 强制刷新回退。
;;
;; 语法
;; ----
;; (pi-oauth-refresh-enabled? config)
;;
;; 参数
;; ----
;; config : alist?
;; 请求配置关联表。
;;
;; 返回值
;; ----
;; boolean
;; 当配置中包含有效的 refresh-oauth-key 过程钩子时返回 #t，否则返回 #f。

(import (liii check) (liii pi ai keyring))

(check-set-mode! 'report-failed)

(check-true
  (not (pi-oauth-refresh-enabled? (list (cons 'api-key "k"))))
) ;check-true

(let ((cfg
        (list (cons 'api-key "k1")
          (cons 'refresh-oauth-key (lambda (config current-key) "new-acc"))
        ) ;list
      ) ;cfg
     ) ;
  (check-true (pi-oauth-refresh-enabled? cfg))
) ;let

(check-true
  (not (pi-oauth-refresh-enabled? (list (cons 'refresh-oauth-key "nope"))))
) ;check-true

(check-report)
