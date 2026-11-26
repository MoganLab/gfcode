;; apply-context-switch
;; 按切换指令操作上下文栈；栈顶为 IncludeRules 帧时对内部栈应用切换。
;;
;; 语法
;; ----
;; (apply-context-switch stack target def)
;;
;; 参数
;; ----
;; stack : list
;; 上下文栈，栈顶在 car；元素可为上下文名字符串或 IncludeRules 帧。
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
  (check (apply-context-switch '("Level0") '(stay) def) => '("Level0"))
  ;; push：压入新上下文
  (check (apply-context-switch '("Level0") '(push "string") def)
    =>
    '("string" "Level0")
  ) ;check
  ;; pop：弹出栈顶
  (check (apply-context-switch '("string" "Level0") '(pop 1) def) => '("Level0"))
  ;; pop 2
  (check (apply-context-switch '("a" "b" "Level0") '(pop 2) def) => '("Level0"))
  ;; pop 带目标名：弹出后压入目标
  (check (apply-context-switch '("string" "Level0") '(pop 1 "Level0") def)
    =>
    '("Level0" "Level0")
  ) ;check
  ;; pop 弹到空：至少保留底层初始上下文
  (check (apply-context-switch '("Level0") '(pop 1) def) => '("Level0"))
  (check (apply-context-switch '("string" "Level0") '(pop 5) def) => '("Level0"))
) ;let

;; IncludeRules 帧：对内部栈应用切换
(let ((def (make-definition "Demo" '("*.demo") "Level0" '() '())))
  (let ((sub-def (make-definition "Sub" '() "Sub0" '() '()))
        (frame (list 'include #f '("Sub0") "host" #f))
       ) ;
    ;; stay 不变
    (check (apply-context-switch (list frame "Level0") '(stay) def)
      =>
      (list (list 'include #f '("Sub0") "host" #f) "Level0")
    ) ;check
    ;; push 进入内部栈
    (check (apply-context-switch (list frame "Level0") '(push "Sub1") def)
      =>
      (list (list 'include #f '("Sub1" "Sub0") "host" #f) "Level0")
    ) ;check
  ) ;let
) ;let

(check-report)
