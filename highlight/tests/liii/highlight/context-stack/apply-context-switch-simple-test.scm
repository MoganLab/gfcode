;; apply-context-switch-simple
;; 对纯上下文名字符串栈应用切换指令（不处理 IncludeRules 帧）。
;;
;; 语法
;; ----
;; (apply-context-switch-simple stack target def)
;;
;; 参数
;; ----
;; stack : list
;; 纯上下文名字符串栈，栈顶在 car。
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
  ;; stay：栈不变
  (check (apply-context-switch-simple '("Level0") '(stay) def) => '("Level0"))
  ;; push：压入新上下文
  (check (apply-context-switch-simple '("Level0") '(push "string") def)
    =>
    '("string" "Level0")
  ) ;check
  ;; pop 1
  (check (apply-context-switch-simple '("string" "Level0") '(pop 1) def)
    =>
    '("Level0")
  ) ;check
  ;; pop 2
  (check (apply-context-switch-simple '("a" "b" "Level0") '(pop 2) def)
    =>
    '("Level0")
  ) ;check
  ;; pop 带目标名
  (check (apply-context-switch-simple '("string" "Level0") '(pop 1 "Level0") def)
    =>
    '("Level0" "Level0")
  ) ;check
  ;; pop 弹到空：至少保留底层初始上下文
  (check (apply-context-switch-simple '("Level0") '(pop 1) def) => '("Level0"))
  (check (apply-context-switch-simple '("string" "Level0") '(pop 5) def)
    =>
    '("Level0")
  ) ;check
) ;let

(check-report)
