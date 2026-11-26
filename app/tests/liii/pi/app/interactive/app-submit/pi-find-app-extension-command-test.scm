;; pi-find-app-extension-command
;; 在默认扩展注册表中查找 slash command，可带或不带前导斜杠。
;;
;; 语法
;; ----
;; (pi-find-app-extension-command name)
;;
;; 参数
;; ----
;; name : string?
;; 命令名，不含前导斜杠（解析自用户输入）。
;;
;; 返回值
;; ----
;; extension-command-def | #f
;; 找到返回命令定义，否则 #f；同时尝试原名与加斜杠名。

(import (scheme base)
  (liii check)
  (liii pi code core extensions)
  (liii pi app interactive app-submit)
) ;import

(check-set-mode! 'report-failed)

(let ((registry (make-extension-registry))
      (command
        (make-extension-command-def "/probe-find"
          "probe"
          (lambda (args ctx) '((status . no-files)))
        ) ;make-extension-command-def
      ) ;command
     ) ;
  (register-command! registry command)
  (set-default-extension-registry! registry)
  (check (extension-command-def-name (pi-find-app-extension-command "probe-find"))
    =>
    "/probe-find"
  ) ;check
  (check (pi-find-app-extension-command "no-such-command-xyz") => #f)
  (set-default-extension-registry! #f)
) ;let

(check-report)
