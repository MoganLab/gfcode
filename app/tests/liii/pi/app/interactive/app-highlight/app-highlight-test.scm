;; pi-app-poll-events!
;; 非阻塞地提交当前版本的高亮请求并处理结果。
;;
;; 语法
;; ----
;; (pi-app-poll-events! app)
;;
;; 参数
;; ----
;; app：使用虚拟终端的应用实例。
;;
;; 返回值
;; ----
;; 忽略；通过通道与卡片缓存观察结果，过期或畸形事件不改变视图。
(import (scheme base)
  (liii check)
  (liii go)
  (liii string)
  (liii tui)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive views syntax)
  (liii pi app interactive views tool-card)
) ;import
(check-set-mode! 'report-failed)

(define app
  (make-pi-app
    :terminal     (make-virtual-terminal 80 24)
    :handler      (lambda args #f)
    :bash-handler (lambda args #f)
  ) ;make-pi-app
) ;define

(define jobs (%pi-app-display-jobs app))

(define (emit . items)
  (for-each (lambda (ev) (chan-send! (pi-app-event-chan app) ev 100)) items)
  (pi-app-poll-events! app)
) ;define

(define raw (apply string-append (make-list 12 "+中文长行\n")))

(define (diff run)
  (list 'diff_result run "e" "p" raw 12 0 1)
) ;define

(define end '(tool_execution_end "e" "edit" (("path" . "p")) #f "Saved"))
(do ((i 0 (+ i 1)))
  ((= i 16))
  (chan-try-send! jobs i)
) ;do
(emit '(run_started 1)
  (diff 1)
  end
  '(assistant_text "done")
  '(agent_settled #f)
) ;emit
(emit '(run_started 2) end (diff 2))
(do ((i 0 (+ i 1)))
  ((= i 16))
  (check (chan-try-recv! jobs #f) => i)
) ;do
(emit)
(check (chan-try-recv! jobs #f) => (list 'diff_highlight_job 2 "e" 1 raw))

(define card (cdar (%pi-app-tool-cards app)))

(define (rows w)
  (component-render card w)
) ;define

(define before (rows 80))

(define narrow (map strip-ansi (rows 7)))

(define data ((%worker-parser) raw))

(define (result run rev payload)
  (list 'diff_highlight_result run "e" rev payload)
) ;define
(emit (result 1 1 data)
  (result 2 2 #f)
  (result 2 1 '(("\x1b;c" (0 2 "Added"))))
) ;emit
(check (rows 80) => before)
(emit (result 2 1 data))

(define after (rows 80))
(check-true (string-contains? (string-join after "\n") "\x1b;[38;2;190;242;200m")
) ;check-true
(check (map strip-ansi after) => (map strip-ansi before))
(emit (result 2 1 #f) (diff 2))
(check-true (eq? after (rows 80)))
(check (map strip-ansi (rows 7)) => narrow)
(tool-card-set-expanded! card #t)
(check-false (string-contains? (string-join (rows 80) "\n") "ctrl+o"))
(tool-card-set-expanded! card #f)
(check (rows 80) => after)
(emit)
(check (chan-try-recv! jobs #f) => #f)

(check-report)
