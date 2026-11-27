;; pi-slash-command-matches
;; 扩展命令补全：默认注册表中的扩展命令动态混入斜杠菜单并参与模糊匹配，
;; 按去斜杠后的规范名去重（"/review" 与 "review" 合并为单个 review 条目）。
;;
;; 语法
;; ----
;; (pi-slash-command-matches text)
;;
;; 参数
;; ----
;; text : string
;; 编辑器当前输入。
;;
;; 返回值
;; ----
;; list | #f
;; 匹配命令列表；无匹配或非命令输入为 #f。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii pi code core extensions)
  (liii pi app interactive slash-command-menu)
  (liii pi code core extension-result)
) ;import

(check-set-mode! 'report-failed)

(define (%no-files-handler)
  (lambda (args ctx) (make-review-no-files #f #f))
) ;define

(let* ((registry (make-extension-registry)) (review-handler (%no-files-handler)))
  ;; 扩展常以带/不带斜杠的多别名注册同一命令
  (register-command! registry
    (make-extension-command-def "/review" "Review changed files" review-handler)
  ) ;register-command!
  (register-command! registry
    (make-extension-command-def "review" "Review changed files" review-handler)
  ) ;register-command!
  (register-command! registry
    (make-extension-command-def "/code-review" "Review diff" review-handler)
  ) ;register-command!
  (set-default-extension-registry! registry)

  ;; 1. /review 命中 review（仅一次：去斜杠去重）
  (let ((matches (pi-slash-command-matches "/review")))
    (check-true (pair? matches))
    (let ((names (map (lambda (m) (cdr (assoc 'name m))) matches)))
      (check-true (pair? (member "review" names)))
      ;; 去重后只出现一次 review
      (check
        (length (filter (lambda (n) (string=? n "review")) names))
        =>
        1
      ) ;check
    ) ;let
  ) ;let

  ;; 2. /rev 模糊匹配命中 review
  (let ((matches (pi-slash-command-matches "/rev")))
    (check-true (pair? matches))
    (check-true
      (pair?
        (find
          (lambda (c) (string=? (cdr (assoc 'name c)) "review"))
          matches
        ) ;find
      ) ;pair?
    ) ;check-true
  ) ;let

  ;; 3. /code 命中 code-review（去斜杠后为 code-review）
  (let ((matches (pi-slash-command-matches "/code")))
    (check-true (pair? matches))
    (check-true
      (pair?
        (find
          (lambda (c) (string=? (cdr (assoc 'name c)) "code-review"))
          matches
        ) ;find
      ) ;pair?
    ) ;check-true
  ) ;let

  ;; 4. 扩展命令与内置命令共存：/ 仍能补全内置 model
  (let ((matches (pi-slash-command-matches "/mod")))
    (check-true (pair? matches))
    (check (cdr (assoc 'name (car matches))) => "model")
  ) ;let

  ;; 5. 无匹配时不留空菜单：/zzz 命中不到任何命令时返回 #f
  (check-false (pi-slash-command-matches "/zzz"))

  (set-default-extension-registry! #f)
) ;let*

;; 6. 注册表未初始化（#f）时回退为仅内置命令，不报错
(let ((matches (pi-slash-command-matches "/exit")))
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

(check-report)
