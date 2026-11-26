;; apply-context-switch-host
;; 宿主规则命中时使用：丢弃 IncludeRules 帧后对外层栈应用切换。
;;
;; 语法
;; ----
;; (apply-context-switch-host stack target def)
;;
;; 参数
;; ----
;; stack : list
;; 上下文栈，栈顶可能是 IncludeRules 帧或普通上下文名。
;;
;; target : list
;; 切换指令：'(stay) | '(push "Name") | '(pop N) | '(pop N "Target")。
;;
;; def : <definition>
;; 语法定义对象，用于在栈弹空时回退到初始上下文。
;;
;; 返回值
;; ----
;; list
;; 切换后的新上下文栈。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight context-stack)
) ;import

(check-set-mode! 'report-failed)

(let ((def (make-definition "Demo" '("*.demo") "Level0" '() '())))
  ;; 栈顶非 IncludeRules 帧：等同 simple 切换
  (check (apply-context-switch-host '("string" "Level0") '(pop 1) def)
    =>
    '("Level0")
  ) ;check
  (check (apply-context-switch-host '("Level0") '(push "tag") def)
    =>
    '("tag" "Level0")
  ) ;check
  (check (apply-context-switch-host '("Level0") '(stay) def) => '("Level0"))

  ;; 栈顶为 IncludeRules 帧：丢弃帧后对外层栈应用切换
  (let ((frame (list 'include #f '("Sub0") "host" #f)))
    (check (apply-context-switch-host (list frame "Level0") '(stay) def)
      =>
      '("Level0")
    ) ;check
    (check (apply-context-switch-host (list frame "Level0") '(push "tag") def)
      =>
      '("tag" "Level0")
    ) ;check
    (check (apply-context-switch-host (list frame "string" "Level0") '(pop 1) def)
      =>
      '("Level0")
    ) ;check
  ) ;let
) ;let

(check-report)
