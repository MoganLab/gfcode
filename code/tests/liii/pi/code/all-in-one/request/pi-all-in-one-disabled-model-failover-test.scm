;; pi-all-in-one-request-stream：未启用模型链式顺延
;; 链中某节点模型已落盘但不在 providers/<provider>.json 的 models 白名单内时，
;; resolve-pi-config 抛 pi-config-error（Model ... is not available for provider ...）。
;; 本文件覆盖请求门面在节点配置解析边界收敛该异常后，按既有链式优先级、故障冷却、
;; 粘性清理与全链枯竭规则继续调度，而不是让该异常直接中断整条链。
;;
;; 语法
;; ----
;; (pi-all-in-one-request-stream provider config messages system-prompt
;;   tools on-event timeout [probe-fn request-fn])
;;
;; 参数
;; ----
;; provider : string
;; 元供应商标识 all-in-one。
;; config : alist
;; 主会话配置（含 config-dir、model-id 与 tools），指向含未启用节点的隔离夹具。
;; messages : list
;; 主会话消息。
;; system-prompt : string
;; 主会话系统提示词。
;; tools、on-event、timeout : any
;; 原样传给真实请求函数。
;; probe-fn、request-fn : procedure (可选)
;; 测试用预检与真实请求函数。
;;
;; 返回值
;; ----
;; <pi-assistant-message>
;; 健康节点的真实响应；全链未启用时返回全链枯竭的结构化 error。
;;
;; 说明
;; ----
;; 覆盖场景：(1) 未启用链首节点记录 [FAIL] 后继续到已启用节点，且未启用节点不
;; 进入真实请求桩、不产生 active_node；(2) 未启用中间节点（探活候选）失败后继续
;; 到剩余健康节点；(3) 未启用粘性节点按真实请求失败路径记录故障、清粘性并顺延；
;; (4) 全部节点未启用时才进入现有 exhausted/recovery 结算，不写未捕获异常堆栈。
;; 探活阶段遇到未启用候选返回 #f、保留原始配置错误且不进入探活请求桩的回归由
;; pi-probe-node-test.scm 直接断言（pi-probe-node 解析节点配置时收敛
;; pi-config-error 并记 [FAIL]）。测试在隔离的 /tmp 配置目录运行，使用假凭据与
;; 探活/请求桩，不访问真实网络，不读写真实用户配置或日志。每个隔离目录独立构造
;; providers 白名单，使指定模型处于已落盘但未启用状态。

(import (scheme base)
  (scheme file)
  (liii check)
  (liii list)
  (liii os)
  (liii path)
  (liii shutil)
  (liii string)
  (liii pi ai message)
  (liii pi ai config model-metadata)
  (liii pi code all-in-one alarm)
  (liii pi code all-in-one request)
  (liii pi code all-in-one state)
  (liii pi code all-in-one types)
) ;import

(check-set-mode! 'report-failed)

;; 未启用模型隔离夹具：DISABLED-DIR 的 coding-deep 链首节点 one 不在
;; models/stub.json 的 models 白名单内（白名单只保留 two），但模型文件
;; models/stub/one.json 仍存在，因此 one 处于已落盘但未启用状态。
;; coding-deep 的第二节点 two 仍启用且凭据有效。
;; 另设 disabled-only 链：两个节点均未启用，用于全链未启用结算回归。

(define DISABLED-DIR
  (path->string
    (path-join (path-temp-dir)
      (string-append "aio-disabled-test-" (number->string (getpid)))
    ) ;path-join
  ) ;path->string
) ;define
(when (file-exists? DISABLED-DIR)
  (rmtree DISABLED-DIR #t)
) ;when
(path-mkdir (path (path-join DISABLED-DIR "models" "stub"))
  :parents  #t
  :exist-ok #t
) ;path-mkdir
(path-write-text (path->string (path-join DISABLED-DIR "all-in-one.json"))
  "{\"provider\":\"all-in-one\",\"probeTimeoutMs\":1234,\"continuous\":false,\"chains\":[{\"id\":\"coding-deep\",\"nodes\":[{\"provider\":\"stub\",\"model\":\"one\"},{\"provider\":\"stub\",\"model\":\"two\",\"thinkingLevel\":\"high\"}]},{\"id\":\"disabled-only\",\"nodes\":[{\"provider\":\"stub\",\"model\":\"one\"},{\"provider\":\"stub\",\"model\":\"three\"}]}]}"
) ;path-write-text
(path-write-text (path->string (path-join DISABLED-DIR "models" "providers.json"))
  "[\"stub\"]"
) ;path-write-text
(path-write-text (path->string (path-join DISABLED-DIR "auth.json"))
  "{\"stub\":{\"type\":\"api_key\",\"key\":\"fixture-key\"}}"
) ;path-write-text
;; 白名单只保留 two：one 与 three 均已落盘模型文件但未启用
(path-write-text (path->string (path-join DISABLED-DIR "models" "stub.json"))
  "{\"api\":\"openai-completions\",\"baseUrl\":\"http://127.0.0.1:1\",\"models\":[\"two\"]}"
) ;path-write-text
(path-write-text (path->string (path-join DISABLED-DIR "models" "stub" "one.json"))
  "{\"id\":\"one\",\"name\":\"one\"}"
) ;path-write-text
(path-write-text (path->string (path-join DISABLED-DIR "models" "stub" "two.json"))
  "{\"id\":\"two\",\"name\":\"two\",\"reasoning\":true,\"contextWindow\":234567}"
) ;path-write-text
(path-write-text (path->string (path-join DISABLED-DIR "models" "stub" "three.json"))
  "{\"id\":\"three\",\"name\":\"three\"}"
) ;path-write-text

;; (1) 未启用链首节点不中断整链：首节点 one 未启用，配置解析边界收敛 pi-config-error，
;; 写 [FAIL]（含 Model ... is not available for provider ... 原始原因）后顺延到已启用的
;; 第二节点 two，由 two 返回响应；未启用节点不产生 active_node、不进入真实请求桩。
;; 首节点未启用属于确定性节点级失败，首轮即用尽一次真实执行预算。
(pi-chain-reset-state!)
(let ((requested '()) (node-events '()) (captured #f))
  (let ((response
          (pi-all-in-one-request-stream "all-in-one"
            (cons
              (cons 'emit
                (lambda (type . payload)
                  (set! node-events (cons (cons type (car payload)) node-events))
                ) ;lambda
              ) ;cons
              (list (cons 'provider "all-in-one")
                (cons 'provider-api "all-in-one")
                (cons 'model-id "coding-deep")
                (cons 'api-key #f)
                (cons 'config-dir DISABLED-DIR)
                (cons 'tools '())
              ) ;list
            ) ;cons
            (list (pi-user-message "work"))
            "system"
            '()
            #f
            60
            (lambda (node timeout-ms config-dir request-fn) #t)
            (lambda (provider config messages system-prompt tools on-event timeout)
              (let ((m (cdr (assoc 'model-id config))))
                (set! requested (cons m requested))
                (set! captured (list provider config))
                (pi-assistant-message (list (pi-text-block "ok")) "stop")
              ) ;let
            ) ;lambda
          ) ;pi-all-in-one-request-stream
        ) ;response
       ) ;
    ;; 仅已启用的 two 进入真实请求桩；未启用 one 零请求
    (check (reverse requested) => '("two"))
    (check (pi-assistant-message-stop-reason response) => "stop")
    (check (car captured) => "stub")
    (check (cdr (assoc 'model-id (cadr captured))) => "two")
    ;; 未启用 one 不产生 active_node，只有 two 的交接事件
    (check
      (filter (lambda (p) (eq? (car p) 'active_node)) node-events)
      =>
      (list (cons 'active_node '("stub" "two" "high" 234567 #t)))
    ) ;check
    (check-true
      (string-contains? (path-read-text (path->string (resolve-alarm-log-path DISABLED-DIR)))
        " [FAIL] provider=stub model=one "
      ) ;string-contains?
    ) ;check-true
    (check-true
      (string-contains? (path-read-text (path->string (resolve-alarm-log-path DISABLED-DIR)))
        "is not available for provider"
      ) ;string-contains?
    ) ;check-true
  ) ;let
) ;let

;; (2) 未启用中间节点（探活候选）也按链式顺延：三节点链 coding-mid 的第二节点
;; two 未启用。one 真实请求失败后，调度器探活 two 失败（此处用探活桩直接返回 #f
;; 模拟 pi-probe-node 对未启用节点的失败），顺延到 three 并真实请求成功。
;; 未启用 two 不进入真实请求桩；探活阶段的原始配置错误记录由 pi-probe-node-test
;; 直接断言（pi-probe-node 解析节点配置时收敛 pi-config-error 并记 [FAIL]）。
;; 这里验证调度链路在探活候选失败后仍能继续到剩余健康节点。

(define MID-DIR
  (path->string
    (path-join (path-temp-dir)
      (string-append "aio-mid-test-" (number->string (getpid)))
    ) ;path-join
  ) ;path->string
) ;define
(when (file-exists? MID-DIR)
  (rmtree MID-DIR #t)
) ;when
(path-mkdir (path (path-join MID-DIR "models" "stub")) :parents #t :exist-ok #t)
(path-write-text (path->string (path-join MID-DIR "all-in-one.json"))
  "{\"provider\":\"all-in-one\",\"probeTimeoutMs\":1234,\"continuous\":false,\"chains\":[{\"id\":\"coding-mid\",\"nodes\":[{\"provider\":\"stub\",\"model\":\"one\"},{\"provider\":\"stub\",\"model\":\"two\"},{\"provider\":\"stub\",\"model\":\"three\"}]}]}"
) ;path-write-text
(path-write-text (path->string (path-join MID-DIR "models" "providers.json"))
  "[\"stub\"]"
) ;path-write-text
(path-write-text (path->string (path-join MID-DIR "auth.json"))
  "{\"stub\":{\"type\":\"api_key\",\"key\":\"fixture-key\"}}"
) ;path-write-text
;; 白名单含 one 与 three，不含 two（two 未启用）
(path-write-text (path->string (path-join MID-DIR "models" "stub.json"))
  "{\"api\":\"openai-completions\",\"baseUrl\":\"http://127.0.0.1:1\",\"models\":[\"one\",\"three\"]}"
) ;path-write-text
(path-write-text (path->string (path-join MID-DIR "models" "stub" "one.json"))
  "{\"id\":\"one\",\"name\":\"one\"}"
) ;path-write-text
(path-write-text (path->string (path-join MID-DIR "models" "stub" "two.json"))
  "{\"id\":\"two\",\"name\":\"two\"}"
) ;path-write-text
(path-write-text (path->string (path-join MID-DIR "models" "stub" "three.json"))
  "{\"id\":\"three\",\"name\":\"three\"}"
) ;path-write-text

(pi-chain-reset-state!)
(let ((probed '()) (requested '()))
  (let ((response
          (pi-all-in-one-request-stream "all-in-one"
            (list (cons 'provider "all-in-one")
              (cons 'model-id "coding-mid")
              (cons 'config-dir MID-DIR)
            ) ;list
            (list (pi-user-message "work"))
            "system"
            '()
            #f
            60
            (lambda (node timeout-ms config-dir request-fn)
              ;; 未启用节点 two 的探活失败；one 与 three 的探活成功
              (set! probed (cons (chain-node-model node) probed))
              (not (equal? (chain-node-model node) "two"))
            ) ;lambda
            (lambda (provider config messages system-prompt tools on-event timeout)
              (let ((m (cdr (assoc 'model-id config))))
                (set! requested (cons m requested))
                (if (equal? m "one")
                  (pi-assistant-message '() :stop-reason "error" :error-message "HTTP 503")
                  (pi-assistant-message (list (pi-text-block "ok")) "stop")
                ) ;if
              ) ;let
            ) ;lambda
          ) ;pi-all-in-one-request-stream
        ) ;response
       ) ;
    (check (pi-assistant-message-stop-reason response) => "stop")
    ;; one 真实失败 -> 探活 two（未启用，失败）-> 探活 three（成功）-> three 真实成功
    (check (reverse probed) => '("two" "three"))
    (check (reverse requested) => '("one" "three"))
  ) ;let
) ;let

;; (3) 未启用粘性节点顺延：先以已启用 one 成功一次使其成为粘性节点，再把白名单
;; 改为只含 two，使 one 变为未启用；粘性复用 one 时配置解析失败，应写 [FAIL]、
;; 清粘性并顺延到 two。验证进程级粘性状态在节点被禁用后能正确失效与重建。
(when (file-exists? (path->string (path-join MID-DIR "logs")))
  (rmtree (path->string (path-join MID-DIR "logs")) #t)
) ;when
(pi-chain-reset-state!)
(let ((requested '()))
  ;; 首轮 one 成功，建立粘性下标 0
  (pi-all-in-one-request-stream "all-in-one"
    (list (cons 'provider "all-in-one")
      (cons 'model-id "coding-mid")
      (cons 'config-dir MID-DIR)
    ) ;list
    (list (pi-user-message "first"))
    "system"
    '()
    #f
    60
    (lambda (node timeout-ms config-dir request-fn) #t)
    (lambda (provider config messages system-prompt tools on-event timeout)
      (set! requested (cons (cdr (assoc 'model-id config)) requested))
      (pi-assistant-message (list (pi-text-block "ok")) "stop")
    ) ;lambda
  ) ;pi-all-in-one-request-stream
  (check (pi-chain-current-sticky-index "coding-mid") => 0)
  ;; 第二轮：把白名单改为只含 two，使 one 变为未启用；粘性复用 one 时配置解析失败，
  ;; 应写 [FAIL]、清粘性并顺延到 two。复用 MID-DIR 但需切换白名单：直接重写 stub.json。
  (path-write-text (path->string (path-join MID-DIR "models" "stub.json"))
    "{\"api\":\"openai-completions\",\"baseUrl\":\"http://127.0.0.1:1\",\"models\":[\"two\"]}"
  ) ;path-write-text
  (let ((second-requested '()))
    (let ((response
            (pi-all-in-one-request-stream "all-in-one"
              (list (cons 'provider "all-in-one")
                (cons 'model-id "coding-mid")
                (cons 'config-dir MID-DIR)
              ) ;list
              (list (pi-user-message "second"))
              "system"
              '()
              #f
              60
              (lambda (node timeout-ms config-dir request-fn) #t)
              (lambda (provider config messages system-prompt tools on-event timeout)
                (set! second-requested (cons (cdr (assoc 'model-id config)) second-requested))
                (pi-assistant-message (list (pi-text-block "ok")) "stop")
              ) ;lambda
            ) ;pi-all-in-one-request-stream
          ) ;response
         ) ;
      ;; 粘性 one 未启用 -> 顺延到 two（本链 one/three 均未启用，仅 two 启用）
      (check (pi-assistant-message-stop-reason response) => "stop")
      ;; one（未启用，不进入请求桩）-> two（启用，成功）；three 也未启用不会到
      (check (reverse second-requested) => '("two"))
      ;; 粘性 one 失败后应清粘性；two 成功后会重新记粘性
      (check (pi-chain-current-sticky-index "coding-mid") => 1)
      (check-true
        (string-contains? (path-read-text (path->string (resolve-alarm-log-path MID-DIR)))
          " [FAIL] provider=stub model=one "
        ) ;string-contains?
      ) ;check-true
    ) ;let
  ) ;let
) ;let

;; (4) 全部节点未启用时走现有全链枯竭结算：disabled-only 链的两个节点 one 与 three
;; 都不在白名单内（DISABLED-DIR 白名单只含 two），发送一次消息后每个节点各记一条
;; [FAIL]，不发出业务 HTTP 请求，最终返回结构化 error。
(when (file-exists? (path->string (path-join DISABLED-DIR "logs")))
  (rmtree (path->string (path-join DISABLED-DIR "logs")) #t)
) ;when
(pi-chain-reset-state!)
(let ((requested '()))
  (let ((response
          (pi-all-in-one-request-stream "all-in-one"
            (list (cons 'provider "all-in-one")
              (cons 'model-id "disabled-only")
              (cons 'config-dir DISABLED-DIR)
            ) ;list
            '()
            ""
            '()
            #f
            60
            (lambda (node timeout-ms config-dir request-fn) #t)
            (lambda (provider config . args)
              (set! requested (cons (cdr (assoc 'model-id config)) requested))
              (pi-assistant-message '() :stop-reason "error" :error-message "unreachable")
            ) ;lambda
          ) ;pi-all-in-one-request-stream
        ) ;response
       ) ;
    ;; 连续失败到全链枯竭：每个候选各用尽一次真实执行预算后 exhausted
    (check (pi-assistant-message-stop-reason response) => "error")
    (check requested => '())
    (check-true
      (string-contains? (path-read-text (path->string (resolve-alarm-log-path DISABLED-DIR)))
        "[EXHAUSTED]"
      ) ;string-contains?
    ) ;check-true
    ;; 两个未启用节点各记一条 [FAIL]
    (check-true
      (string-contains? (path-read-text (path->string (resolve-alarm-log-path DISABLED-DIR)))
        " [FAIL] provider=stub model=one "
      ) ;string-contains?
    ) ;check-true
    (check-true
      (string-contains? (path-read-text (path->string (resolve-alarm-log-path DISABLED-DIR)))
        " [FAIL] provider=stub model=three "
      ) ;string-contains?
    ) ;check-true
  ) ;let
) ;let

(when (file-exists? DISABLED-DIR)
  (rmtree DISABLED-DIR #t)
) ;when
(when (file-exists? MID-DIR)
  (rmtree MID-DIR #t)
) ;when

(check-report)
