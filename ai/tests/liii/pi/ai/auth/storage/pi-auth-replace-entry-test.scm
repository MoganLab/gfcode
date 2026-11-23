;; pi-auth-replace-entry
;; 替换（或追加）auth.json alist 中某 provider 的条目，其余原样保留。
;;
;; 语法
;; ----
;; (pi-auth-replace-entry alist p-str entry-fields) -> list?
;;
;; 参数
;; ----
;; alist : list?
;; 现有 auth.json 数据（provider → 条目字段 alist）。
;;
;; p-str : string?
;; 目标 provider id。
;;
;; entry-fields : list?
;; 新条目字段 alist。
;;
;; 返回值
;; ----
;; list?
;; 更新后的 alist；目标条目移到末尾，键可为 symbol 的旧条目也能被替换。

(import (liii check) (liii pi ai auth storage))

(check-set-mode! 'report-failed)

;; 追加
(check (pi-auth-replace-entry '() "kimi-coding" '(("type" . "oauth")))
  =>
  '(("kimi-coding" ("type" . "oauth")))
) ;check

;; 替换已有条目，保留其它
(let* ((alist '(("deepseek" ("type" . "api_key") ("key" . "sk"))
                ("kimi-coding" ("type" . "api_key") ("key" . "old")))
       ) ;alist
       (updated (pi-auth-replace-entry alist "kimi-coding" '(("type" . "oauth"))))
      ) ;
  (check (length updated) => 2)
  (check (assoc "deepseek" updated) => (car alist))
  (check (cdr (assoc "kimi-coding" updated)) => '(("type" . "oauth")))
) ;let*

;; symbol 键的旧条目同样被替换
(let ((updated
        (pi-auth-replace-entry '((deepseek ("key" . "sk")))
          "deepseek"
          '(("key" . "new"))
        ) ;pi-auth-replace-entry
      ) ;updated
     ) ;
  (check (length updated) => 1)
  (check (cdr (assoc "deepseek" updated)) => '(("key" . "new")))
) ;let

(check-report)
