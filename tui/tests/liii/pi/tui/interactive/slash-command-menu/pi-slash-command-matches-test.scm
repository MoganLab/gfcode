;; pi-slash-command-matches
;; 匹配输入行中的斜杠命令，返回候选命令列表。
;;
;; 语法
;; ----
;; (pi-slash-command-matches text)
;;
;; 参数
;; ----
;; text : string?
;; 用户输入的当前文本。
;;
;; 返回值
;; ----
;; list?
;; 匹配到的命令 alist 列表；若无匹配或已进入参数输入则返回 #f。

(import (scheme base) (liii check) (liii pi tui interactive slash-command-menu))

(check-set-mode! 'report-failed)

;; 1. 前缀 / 匹配所有斜杠命令
(let ((matches (pi-slash-command-matches "/")))
  (check-true (pair? matches))
  (check (> (length matches) 0) => #t)
) ;let

;; 2. 部分匹配
(let ((matches (pi-slash-command-matches "/mod")))
  (check-true (pair? matches))
  (check (cdr (assoc 'name (car matches))) => "model")
) ;let

(let ((matches (pi-slash-command-matches "/log")))
  (check-true (pair? matches))
  (check (cdr (assoc 'name (car matches))) => "login")
) ;let

;; /exit 命令注册并参与斜杠菜单匹配
(let ((matches (pi-slash-command-matches "/exit")))
  (check-true (pair? matches))
  ;; 候选项中包含 exit 及其描述 Exit gf
  (let ((exit-cmd (find (lambda (c) (string=? (cdr (assoc 'name c)) "exit")) matches)))
    (check-true (pair? exit-cmd))
    (check (cdr (assoc 'description exit-cmd)) => "Exit gf")
  ) ;let
) ;let

;; /e 与 /ex 模糊匹配能命中 exit 候选
(let ((matches (pi-slash-command-matches "/ex")))
  (check-true (pair? matches))
  (check-true
    (pair?
      (find
        (lambda (c) (string=? (cdr (assoc 'name c)) "exit"))
        matches
      ) ;find
    ) ;pair?
  ) ;check-true
) ;let

;; 3. 包含空格时不匹配
(check-false (pi-slash-command-matches "/model "))

;; 4. 非斜杠开头不匹配
(check-false (pi-slash-command-matches "model"))

;; 5. /exit 带空格（进入参数输入）不再触发命令补全菜单
(check-false (pi-slash-command-matches "/exit "))

(check-report)
