;; pi-auth-builtin-provider-ids
;; 内置 provider id 全集（白名单缺失/空时回退用）；排除伪 provider all-in-one。
;;
;; 语法
;; ----
;; (pi-auth-builtin-provider-ids) -> (listof string?)
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; (listof string?)
;; 按字典序升序排列的内置 provider id 列表，不含 "all-in-one"。

(import (liii check) (liii list) (liii sort) (liii pi ai auth whitelist))

(check-set-mode! 'report-failed)

;; 1. 返回非空字符串列表，且不含 all-in-one
(let ((ids (pi-auth-builtin-provider-ids)))
  (check-true (and (pair? ids) (every string? ids) #t))
  (check-false (member "all-in-one" ids))
  ;; 已知内置 provider 应在其中
  (check-true (and (member "deepseek" ids) (member "kimi-coding" ids) #t))
) ;let

;; 2. 列表按字典序升序排列
(let ((ids (pi-auth-builtin-provider-ids)))
  (check ids => (list-sort string<? ids))
) ;let

;; 3. 无重复元素：对每个已有 id 合并不增长列表
(let ((ids (pi-auth-builtin-provider-ids)))
  (let loop
    ((rest ids) (ok #t))
    (cond
     ((null? rest)
      (check-true ok)
      ;; 整体长度 == 合并任一成员后长度（无重复则不增长）
      (check (length (pi-auth-merge-provider-id ids (car ids))) => (length ids))
     ) ;
     (else
       (loop (cdr rest)
         (and ok (= (length (pi-auth-merge-provider-id ids (car rest))) (length ids)))
       ) ;loop
     ) ;else
    ) ;cond
  ) ;let
) ;let

(check-report)
