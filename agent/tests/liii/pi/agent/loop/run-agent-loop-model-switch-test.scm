;; run-agent-loop-model-switch
;; 测试 run-agent-loop 的 prepare-request 钩子：每次新 Provider 请求前
;; 解析最新选择，使运行中切模立即对下一次请求生效。
;;
;; 语法
;; ----
;; (run-agent-loop config initial-messages system-prompt (emit #f) (timeout 600)
;;   (max-turns 0) (session-timeout 0) (compaction #f) (request-fn #f) (emit-initial? #t))
;;
;; 参数
;; ----
;; config : list?，含可选 prepare-request 过程的 Agent 配置 alist。
;; 其余参数同 run-agent-loop。
;;
;; 返回值
;; ----
;; list?，执行完成后的完整消息历史列表。

(import (scheme base)
  (liii list)
  (liii check)
  (liii pi ai config runtime)
  (liii pi agent loop)
  (liii pi ai message)
) ;import

(check-set-mode! 'report-failed)

(define (make-text-response text)
  (pi-assistant-message (list (list (cons 'type "text") (cons 'text text)))
    :stop-reason "stop"
    :usage       '((input . 1) (output . 1) (total . 2))
  ) ;pi-assistant-message
) ;define

(define (make-tool-use-response)
  (pi-assistant-message
    (list
      (list (cons 'type "toolCall")
        (cons 'id "call_1")
        (cons 'name "bash")
        (cons 'arguments (list (cons "command" "echo hi")))
      ) ;list
    ) ;list
    :stop-reason "toolUse"
    :usage       '((input . 1) (output . 1) (total . 2))
  ) ;pi-assistant-message
) ;define

(define (ok-exec name . args)
  (list
    (cons 'content (list (list (cons 'type "text") (cons 'text "tool output"))))
    (cons 'isError #f)
  ) ;list
) ;define

;; 捕获每次请求实际使用的 provider/model（取自传入的 config）

(define (make-request-observer req-cfgs)
  (lambda (provider config messages sys-prompt tools on-ev timeout)
    (set! req-cfgs
      (append req-cfgs
        (list (list (cons 'provider (pi-cfg-ref config 'provider))
                (cons 'model-id (pi-cfg-ref config 'model-id))
              ) ;list
        ) ;list
      ) ;append
    ) ;set!
    (make-text-response "done")
  ) ;lambda
) ;define

;; -----------------------------------------------------------------------------
;; 测试项 1: 第一次请求使用 A 并返回 toolUse；工具执行期间发布 B；
;; 第二次请求必须使用 B。
;; -----------------------------------------------------------------------------
(let* ((eff-box (vector (list (cons 'provider "google")
                          (cons 'model-id "gemini-A")
                          (cons 'models-store '())
                        ) ;list
                ) ;vector
       ) ;eff-box
       (selections '())
       (prepare
         (lambda (cfg)
           ;; 排空 selections（latest-wins），应用最后一项到 eff-box
           (let loop
             ((last #f))
             (let ((s
                     (if (pair? selections)
                       (begin
                         (set! selections (cdr selections))
                         (car selections)
                       ) ;begin
                       #f
                     ) ;if
                   ) ;s
                  ) ;
               (if (pair? s) (loop s) last)
             ) ;let
           ) ;let
           (if (vector? eff-box) (vector-ref eff-box 0) cfg)
         ) ;lambda
       ) ;prepare
       (req-cfgs '())
       (round 0)
       (request-fn
         (lambda (provider config messages sys-prompt tools on-ev timeout)
           (set! round (+ round 1))
           (set! req-cfgs
             (append req-cfgs
               (list (list (cons 'provider (pi-cfg-ref config 'provider))
                       (cons 'model-id (pi-cfg-ref config 'model-id))
                     ) ;list
               ) ;list
             ) ;append
           ) ;set!
           ;; 第 1 轮返回 toolUse；工具执行期间“切模”到 B
           (if (= round 1)
             (begin
               ;; 模拟工具执行期间发布 B：更新 eff-box
               (vector-set! eff-box
                 0
                 (list (cons 'provider "zai") (cons 'model-id "glm-B") (cons 'models-store '()))
               ) ;vector-set!
               (make-tool-use-response)
             ) ;begin
             (make-text-response "done")
           ) ;if
         ) ;lambda
       ) ;request-fn
       (cfg (list (cons 'tools '("bash"))
              (cons 'execute-tool-call ok-exec)
              (cons 'provider "google")
              (cons 'model-id "gemini-A")
              (cons 'models-store '())
              (cons 'prepare-request prepare)
            ) ;list
       ) ;cfg
       (res (run-agent-loop cfg (list (pi-user-message "hi")) "" #f 10 0 0 #f request-fn)
       ) ;res
      ) ;
  (check (length req-cfgs) => 2)
  (check (cdr (assoc 'model-id (car req-cfgs))) => "gemini-A")
  (check (cdr (assoc 'model-id (cadr req-cfgs))) => "glm-B")
) ;let*

;; -----------------------------------------------------------------------------
;; 测试项 2: 工具期间连续发布 B、C；第二次请求只使用 C（latest-wins）
;; -----------------------------------------------------------------------------
(let* ((eff-box (vector (list (cons 'provider "google") (cons 'model-id "A") (cons 'models-store '()))
                ) ;vector
       ) ;eff-box
       (pending '())
       (prepare
         (lambda (cfg)
           ;; 应用 pending 列表最后一项
           (when (pair? pending)
             (let ((last (car (reverse pending))))
               (set! pending '())
               (vector-set! eff-box
                 0
                 (list (cons 'provider (car last))
                   (cons 'model-id (cadr last))
                   (cons 'models-store '())
                 ) ;list
               ) ;vector-set!
             ) ;let
           ) ;when
           (vector-ref eff-box 0)
         ) ;lambda
       ) ;prepare
       (req-cfgs '())
       (round 0)
       (request-fn
         (lambda (provider config messages sys-prompt tools on-ev timeout)
           (set! round (+ round 1))
           (set! req-cfgs
             (append req-cfgs
               (list (list (cons 'provider (pi-cfg-ref config 'provider))
                       (cons 'model-id (pi-cfg-ref config 'model-id))
                     ) ;list
               ) ;list
             ) ;append
           ) ;set!
           (if (= round 1)
             (begin
               ;; 工具执行期间连续发布 B、C
               (set! pending '(("google" "B") ("zai" "C")))
               (make-tool-use-response)
             ) ;begin
             (make-text-response "done")
           ) ;if
         ) ;lambda
       ) ;request-fn
       (cfg (list (cons 'tools '("bash"))
              (cons 'execute-tool-call ok-exec)
              (cons 'provider "google")
              (cons 'model-id "A")
              (cons 'models-store '())
              (cons 'prepare-request prepare)
            ) ;list
       ) ;cfg
       (res (run-agent-loop cfg (list (pi-user-message "hi")) "" #f 10 0 0 #f request-fn)
       ) ;res
      ) ;
  (check (length req-cfgs) => 2)
  (check (cdr (assoc 'model-id (car req-cfgs))) => "A")
  (check (cdr (assoc 'model-id (cadr req-cfgs))) => "C")
  (check (cdr (assoc 'provider (cadr req-cfgs))) => "zai")
) ;let*

;; -----------------------------------------------------------------------------
;; 测试项 3: 未配置 prepare-request 时现有单轮和多轮行为不变
;; -----------------------------------------------------------------------------
(let* ((round 0)
       (request-fn (lambda (provider config messages sys-prompt tools on-ev timeout)
                     (set! round (+ round 1))
                     (if (= round 1) (make-tool-use-response) (make-text-response "done"))
                   ) ;lambda
       ) ;request-fn
       (cfg (list (cons 'tools '("bash"))
              (cons 'execute-tool-call ok-exec)
              (cons 'provider "google")
              (cons 'model-id "gemini-A")
              (cons 'models-store '())
            ) ;list
       ) ;cfg
       (res (run-agent-loop cfg (list (pi-user-message "hi")) "" #f 10 0 0 #f request-fn)
       ) ;res
      ) ;
  (check round => 2)
  (check (length res) => 4)
) ;let*

;; -----------------------------------------------------------------------------
;; 测试项 4: 自然停止且没有后续消息时，仅切换模型不额外触发请求
;; prepare-request 返回新模型但不驱动请求：单轮即结束
;; -----------------------------------------------------------------------------
(let* ((called 0)
       (prepare (lambda (cfg) (set! called (+ called 1)) cfg))
       (request-fn (lambda (provider config messages sys-prompt tools on-ev timeout)
                     (make-text-response "done")
                   ) ;lambda
       ) ;request-fn
       (cfg (list (cons 'provider "google")
              (cons 'model-id "gemini-A")
              (cons 'models-store '())
              (cons 'prepare-request prepare)
            ) ;list
       ) ;cfg
       (res (run-agent-loop cfg (list (pi-user-message "hi")) "" #f 10 0 0 #f request-fn)
       ) ;res
      ) ;
  ;; prepare 在单轮中被调用一次（请求边界），自然结束不额外触发请求
  (check called => 1)
  (check (length res) => 2)
) ;let*

(check-report)
