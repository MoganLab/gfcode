;; tool_execution_end 扩展事件桥
;; 验证工具执行结束后向扩展事件系统派发 tool_execution_end，
;; 携带 name、input、result 文本与最终 isError 状态；被拦截的工具不派发。
;;
;; 语法
;; ----
;; (pi-execute-one-tool-call-with-status call emit timeout opt-config)
;;
;; 参数
;; ----
;; opt-config 含 execute-tool-call 与 emit-extension-event。
;;
;; 返回值
;; ----
;; 扩展 emitter 收到 (tool_execution_end payload)；payload 为
;; ((id . ..) (name . ..) (input . ..) (result . ..) (isError . ..))。
;; tool_call 被 block 时不产生 tool_execution_end 扩展事件。

(import (scheme base)
  (liii check)
  (liii pi agent tools)
  (liii pi ai tools result)
) ;import

(check-set-mode! 'report-failed)

;; 1. 成功 write：扩展收到 tool_execution_end，isError=#f，input 保留 path
(let* ((events '())
       (cfg
         (list (cons 'execute-tool-call (lambda (name args . opts) (pi-tool-result "ok" #f)))
           (cons 'emit-extension-event
             (lambda (event-type payload)
               (set! events (cons (cons event-type payload) events))
               '((action . continue))
             ) ;lambda
           ) ;cons
         ) ;list
       ) ;cfg
       (call '((id . "c1") (name . "write") (arguments ("path" . "a.scm"))))
      ) ;
  (pi-execute-one-tool-call-with-status call #f 10 cfg)
  (let* ((end (assq 'tool_execution_end events)) (payload (and end (cdr end))))
    (check-true (and end #t))
    (check (cdr (assoc 'name payload)) => "write")
    (check (cdr (assoc 'isError payload)) => #f)
    (check
      (cdr (assoc "path" (cdr (assoc 'input payload))))
      =>
      "a.scm"
    ) ;check
  ) ;let*
) ;let*

;; 2. 失败执行：isError=#t 如实上报（自动审查据此忽略失败编辑）
(let* ((events '())
       (cfg
         (list (cons 'execute-tool-call (lambda (name args . opts) (pi-tool-result "boom" #t)))
           (cons 'emit-extension-event
             (lambda (event-type payload)
               (set! events (cons (cons event-type payload) events))
               '((action . continue))
             ) ;lambda
           ) ;cons
         ) ;list
       ) ;cfg
       (call '((id . "c2") (name . "edit") (arguments ("path" . "b.py"))))
      ) ;
  (pi-execute-one-tool-call-with-status call #f 10 cfg)
  (check
    (cdr (assoc 'isError (cdr (assq 'tool_execution_end events))))
    =>
    #t
  ) ;check
) ;let*

;; 3. 被拦截的工具：不派发 tool_execution_end 扩展事件
(let* ((events '())
       (cfg
         (list
           (cons 'emit-extension-event
             (lambda (event-type payload)
               (set! events (cons event-type events))
               '((action . block) (reason . "no"))
             ) ;lambda
           ) ;cons
         ) ;list
       ) ;cfg
       (call '((id . "c3") (name . "write") (arguments)))
      ) ;
  (pi-execute-one-tool-call-with-status call #f 10 cfg)
  (check (memq 'tool_execution_end events) => #f)
) ;let*

(check-report)
