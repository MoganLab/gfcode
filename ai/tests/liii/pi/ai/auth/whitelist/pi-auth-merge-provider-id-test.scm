;; pi-auth-merge-provider-id
;; 不重复追加 provider id 到列表，保持既有顺序，已存在则原样返回。
;;
;; 语法
;; ----
;; (pi-auth-merge-provider-id ids p-str) -> (listof string?)
;;
;; 参数
;; ----
;; ids   : (listof string?) 既有白名单。
;; p-str : string?          待追加的 provider id。
;;
;; 返回值
;; ----
;; (listof string?)
;; 合并后的白名单，p-str 不存在时追加到末尾，存在时原样返回 ids。

(import (liii check) (liii pi ai auth whitelist))

(check-set-mode! 'report-failed)

;; 1. 追加新元素到末尾，保留既有顺序
(check (pi-auth-merge-provider-id '("a" "b") "c") => '("a" "b" "c"))

;; 2. 已存在则原样返回（不重复、不重排）
(check (pi-auth-merge-provider-id '("a" "b" "c") "b") => '("a" "b" "c"))

;; 3. 空列表时返回单元素列表
(check (pi-auth-merge-provider-id '() "deepseek") => '("deepseek"))

;; 4. 不修改原始列表的成员
(let ((ids '("a" "b")))
  (check (pi-auth-merge-provider-id ids "c") => '("a" "b" "c"))
  ;; 原列表不变（仅做只读 member/append）
  (check ids => '("a" "b"))
) ;let

(check-report)
