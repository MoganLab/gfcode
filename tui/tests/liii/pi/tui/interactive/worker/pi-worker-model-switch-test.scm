;; pi-worker-model-switch
;; Worker 运行中切模集成测试：通过 request-selection-chan + prepare-request
;; 验证 A 请求 -> 工具执行 -> /model 选 B -> B 续轮请求。
;;
;; 语法
;; ----
;; (pi-worker-make-prepare-request eff-box request-selection-chan parsed)
;;
;; 参数
;; ----
;; eff-box : vector?，effective-cfg 容器
;; request-selection-chan : chan?，最新请求选择通道
;; parsed : list?，命令行参数
;;
;; 返回值
;; ----
;; procedure?，prepare-request 过程

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii go)
  (liii pi ai message)
  (liii pi ai config runtime)
  (liii pi code cli args)
  (liii pi code config)
  (liii pi agent loop)
  (liii pi tui interactive worker-model)
) ;import

(check-set-mode! 'report-failed)

(define TMP-AGENT-DIR
  (path->string (path-join (path-temp-dir) "pi-worker-model-switch-test"))
) ;define

(when (file-exists? TMP-AGENT-DIR)
  (rmtree TMP-AGENT-DIR)
) ;when

(path-mkdir TMP-AGENT-DIR :parents #t :exist-ok #t)
(path-write-text (path->string (path-join (path TMP-AGENT-DIR) (path "auth.json")))
  "{\"google\":{\"type\":\"api_key\",\"key\":\"fixture-google-key\"},\"zai\":{\"type\":\"api_key\",\"key\":\"fixture-zai-key\"}}"
) ;path-write-text

(define (make-cfg)
  (let* ((env (list (cons "PI_CODING_AGENT_DIR" TMP-AGENT-DIR)))
         (parsed (parse-pi-args '()))
         (cfg (resolve-pi-config parsed env))
        ) ;
    (values cfg parsed)
  ) ;let*
) ;define

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

;; -----------------------------------------------------------------------------
;; 测试项 1: A 请求 -> 工具执行 -> /model 选 B -> B 续轮请求
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
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
                 ;; 工具执行期间发布 B：模拟 /model 选 B 发布选择快照
                 (chan-send! chan (list "zai" "glm-5" "medium" #f) 1000)
                 (make-tool-use-response)
               ) ;begin
               (make-text-response "done")
             ) ;if
           ) ;lambda
         ) ;request-fn
         (job-cfg
           (pi-cfg-merge cfg
             (list (cons 'tools '("bash"))
               (cons 'execute-tool-call ok-exec)
               (cons 'prepare-request prepare)
             ) ;list
           ) ;pi-cfg-merge
         ) ;job-cfg
        ) ;
    (let ((res (run-agent-loop job-cfg
                 (list (pi-user-message "hi"))
                 ""
                 #f
                 10
                 0
                 0
                 #f
                 request-fn
               ) ;run-agent-loop
          ) ;res
         ) ;
      (check (length req-cfgs) => 2)
      (check (cdr (assoc 'model-id (car req-cfgs))) => "gemini-3.8-flash")
      (check (cdr (assoc 'model-id (cadr req-cfgs))) => "glm-5")
      (check (cdr (assoc 'provider (cadr req-cfgs))) => "zai")
      ;; 跨 provider 切换后 provider-api 也更新（augment 已执行）
      (check (pi-cfg-ref (pi-effective-cfg-ref eff-box) 'provider) => "zai")
    ) ;let
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 2: A 请求 -> steering + B -> B 请求
;; steering 在自然停止前注入；prepare-request 在下一轮请求前读取 chan 里的 B
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
         (req-cfgs '())
         (round 0)
         (steer-count (vector 0))
         (get-steering
           (lambda ()
             (vector-set! steer-count 0 (+ 1 (vector-ref steer-count 0)))
             ;; 第 1 次轮询无；第 2 次（自然停止前）返回一条 steering，并发布 B
             (if (= (vector-ref steer-count 0) 2)
               (begin
                 (chan-send! chan (list "zai" "glm-5" "medium" #f) 1000)
                 (list "继续")
               ) ;begin
               '()
             ) ;if
           ) ;lambda
         ) ;get-steering
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
             (make-text-response (string-append "reply-" (number->string round)))
           ) ;lambda
         ) ;request-fn
         (job-cfg (pi-cfg-merge cfg
                    (list (cons 'tools '())
                      (cons 'get-steering-messages get-steering)
                      (cons 'prepare-request prepare)
                    ) ;list
                  ) ;pi-cfg-merge
         ) ;job-cfg
        ) ;
    (run-agent-loop job-cfg
      (list (pi-user-message "hi"))
      ""
      #f
      10
      0
      0
      #f
      request-fn
    ) ;run-agent-loop
    (check (length req-cfgs) => 2)
    ;; 第 1 轮仍是 google（A）；第 2 轮（steering 后）已是 zai/glm-5（B）
    (check (cdr (assoc 'model-id (car req-cfgs))) => "gemini-3.8-flash")
    (check (cdr (assoc 'model-id (cadr req-cfgs))) => "glm-5")
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 3: A 请求 -> follow-up + B -> B 请求
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
         (req-cfgs '())
         (round 0)
         (fu-count (vector 0))
         (get-follow-up
           (lambda ()
             (vector-set! fu-count 0 (+ 1 (vector-ref fu-count 0)))
             (if (= (vector-ref fu-count 0) 1)
               (begin
                 (chan-send! chan (list "zai" "glm-5" "medium" #f) 1000)
                 (list "收尾")
               ) ;begin
               '()
             ) ;if
           ) ;lambda
         ) ;get-follow-up
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
             (make-text-response "ok")
           ) ;lambda
         ) ;request-fn
         (job-cfg (pi-cfg-merge cfg
                    (list (cons 'tools '())
                      (cons 'get-follow-up-messages get-follow-up)
                      (cons 'prepare-request prepare)
                    ) ;list
                  ) ;pi-cfg-merge
         ) ;job-cfg
        ) ;
    (run-agent-loop job-cfg
      (list (pi-user-message "hi"))
      ""
      #f
      10
      0
      0
      #f
      request-fn
    ) ;run-agent-loop
    (check (length req-cfgs) => 2)
    (check (cdr (assoc 'model-id (car req-cfgs))) => "gemini-3.8-flash")
    (check (cdr (assoc 'model-id (cadr req-cfgs))) => "glm-5")
  ) ;let*
) ;let*-values

;; -----------------------------------------------------------------------------
;; 测试项 4: run 结束后下一条普通消息继续使用最后选择，不发生 A/B 回摆
;; 两次独立 run-agent-loop 复用同一 eff-box：第一次切到 B；第二次 prepare 时
;; chan 为空，沿用 eff-box 的 B，不回退 A。
;; -----------------------------------------------------------------------------
(let*-values (((cfg parsed) (make-cfg)))
  (let* ((eff-box (pi-make-effective-cfg-box cfg))
         (chan (make-chan 4))
         (prepare (pi-worker-make-prepare-request eff-box chan parsed))
         (req-cfgs '())
         (request-fn
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
         ) ;request-fn
         (job-cfg (pi-cfg-merge cfg (list (cons 'tools '()) (cons 'prepare-request prepare)))
         ) ;job-cfg
        ) ;
    ;; 第一次 run：发布 B，单轮请求使用 B
    (chan-send! chan (list "zai" "glm-5" "medium" #f) 1000)
    (run-agent-loop job-cfg
      (list (pi-user-message "hi"))
      ""
      #f
      10
      0
      0
      #f
      request-fn
    ) ;run-agent-loop
    ;; 第二次 run：chan 已空，沿用 eff-box 的 B，不回退 google/A
    (run-agent-loop job-cfg
      (list (pi-user-message "again"))
      ""
      #f
      10
      0
      0
      #f
      request-fn
    ) ;run-agent-loop
    (check (length req-cfgs) => 2)
    (check (cdr (assoc 'model-id (car req-cfgs))) => "glm-5")
    (check (cdr (assoc 'model-id (cadr req-cfgs))) => "glm-5")
  ) ;let*
) ;let*-values

(rmtree TMP-AGENT-DIR)

(check-report)
