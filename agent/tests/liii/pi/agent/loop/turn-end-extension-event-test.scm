;; turn_end 扩展事件桥
;; Agent 结算时向扩展事件系统派发 turn_end（携带 turn 序号，先于 agent_end）。
;;
;; 语法
;; ----
;; (run-agent-loop config initial-messages system-prompt emit ...)
;;
;; 参数
;; ----
;; config 含 emit-extension-event；其余同 run-agent-loop。
;;
;; 返回值
;; ----
;; 扩展 emitter 依次收到 agent_start、turn_start、turn_end、agent_end；
;; turn_end payload 为 ((turn . N))。
;; 无 emit-extension-event 时不派发扩展事件，不影响主循环。

(import (scheme base)
  (liii check)
  (liii pi ai message)
  (liii pi agent loop)
) ;import

(check-set-mode! 'report-failed)

(let* ((events '())
       (cfg (list '(tools)
              '(provider . "google")
              '(models-store)
              (cons 'emit-extension-event
                (lambda (event-type payload)
                  (set! events (cons (cons event-type payload) events))
                  '((action . continue))
                ) ;lambda
              ) ;cons
            ) ;list
       ) ;cfg
       (mock-req
         (lambda (provider cfg msgs sp tools on-stream to)
           (pi-assistant-message (list (list (cons 'type "text") (cons 'text "ok")))
             :stop-reason "stop"
             :usage '((input . 1) (output . 1) (total . 2))
           ) ;pi-assistant-message
         ) ;lambda
       ) ;mock-req
      ) ;
  (run-agent-loop cfg (list (pi-user-message "hi")) "" #f 10 0 0 #f mock-req)
  (let ((names (reverse (map car events))))
    (check-true (pair? (memq 'turn_end names)))
    ;; turn_end 在 agent_end 之前
    (check-true (> (length (memq 'turn_end names)) (length (memq 'agent_end names))))
    (check (cdr (assoc 'turn (cdr (assq 'turn_end events)))) => 0)
  ) ;let
) ;let*

(check-report)
