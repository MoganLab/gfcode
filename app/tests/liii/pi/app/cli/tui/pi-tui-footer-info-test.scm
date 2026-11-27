;; pi-tui-footer-info
;; TUI 页脚与 make-pi-app 共用的启动配置提取。
;;
;; 语法
;; ----
;; (pi-tui-footer-info parsed) -> list
;;
;; 参数
;; ----
;; parsed : alist
;; parse-pi-args 的解析结果。
;;
;; 返回值
;; ----
;; list
;; (provider model-id thinking-level supports-thinking default-thinking-level
;;  config-dir models default-model hide-thinking model-thinking-levels)
;;
;; 注意：
;; 该函数用 catch 兜住配置解析异常并回退到 CLI 原始参数，因此**兜底值一旦
;; 与真实配置不符，就无法从返回值区分「解析成功」和「解析失败」**。
;; 本测试用真实 fixture 目录断言 provider/model/thinking-level 均来自
;; settings.json，防止库漏导出符号（unbound variable）导致静默回落到
;; deepseek/deepseek-flash。

(import (liii check)
  (liii os)
  (liii path)
  (liii tempfile)
  (liii pi code config)
  (only (liii pi app interactive worker) %worker-job-cfg)
  (liii pi code cli args)
  (liii pi app cli tui)
) ;import

(check-set-mode! 'report-failed)

(define FIXTURE-DIR
  (if (file-exists? "tests/fixtures/model-thinking")
    "tests/fixtures/model-thinking"
    "tools/pi/tests/fixtures/model-thinking"
  ) ;if
) ;define

;; 用 putenv 让 pi-tui-footer-info 内部的 get-environment-variables 命中 fixture；
;; 结束时还原，避免污染同进程内后续测试

(define (copy-dir-contents src-dir dst-dir)
  (vector-for-each
    (lambda (name)
      (let ((src (path->string (path-join src-dir name)))
            (dst (path->string (path-join dst-dir name)))
           ) ;
        (if (path-dir? src)
          (begin
            (path-mkdir dst)
            (copy-dir-contents src dst)
          ) ;begin
          (path-copy src dst)
        ) ;if
      ) ;let
    ) ;lambda
    (listdir src-dir)
  ) ;vector-for-each
) ;define

(define (with-config-dir thunk . empty?)
  (with-temp-dir
    (lambda (tmp-dir)
      (when (null? empty?)
        (copy-dir-contents (path->string (path-absolute (path FIXTURE-DIR))) tmp-dir)
      ) ;when
      (let ((saved (getenv "GF_CONFIG_DIR")) (saved-pi (getenv "PI_CODING_AGENT_DIR")))
        (putenv "GF_CONFIG_DIR" tmp-dir)
        (unsetenv "PI_CODING_AGENT_DIR")
        (dynamic-wind (lambda () #f)
          thunk
          (lambda ()
            (if saved (putenv "GF_CONFIG_DIR" saved) (unsetenv "GF_CONFIG_DIR"))
            (when saved-pi
              (putenv "PI_CODING_AGENT_DIR" saved-pi)
            ) ;when
          ) ;lambda
        ) ;dynamic-wind
      ) ;let
    ) ;lambda
    "gf-tui-footer-test-"
  ) ;with-temp-dir
) ;define

;; 1. provider / model 来自 settings.json，而非兜底
(let ((info (with-config-dir (lambda () (pi-tui-footer-info (parse-pi-args '()))))))
  (check (list-ref info 0) => "google")
  (check (list-ref info 1) => "gemini-3.8-flash")
  ;; settings.defaultThinkingLevel = "low"，被 per-model 覆盖为 "high"
  (check (list-ref info 2) => "high")
  (check (list-ref info 3) => #t)
  ;; 默认级别为 settings 原始值
  (check (list-ref info 4) => "low")
) ;let

;; 2. per-model 覆盖表被原样传给 make-pi-app（/model 切换时使用）
(let ((info (with-config-dir (lambda () (pi-tui-footer-info (parse-pi-args '()))))))
  (check (list-ref info 9)
    =>
    '(("google/gemini-3.8-flash" . "high") ("google/plain-model" . "max"))
  ) ;check
) ;let

;; 3. 显式 --thinking 压过 per-model 覆盖与全局默认
(let ((info
        (with-config-dir
          (lambda () (pi-tui-footer-info (parse-pi-args '("--thinking"
                                                          "minimal"))))
        ) ;with-config-dir
      ) ;info
     ) ;
  (check (list-ref info 2) => "minimal")
) ;let

;; 空配置下，页脚与 worker 首轮请求从同一目录解析，且未走异常兜底。
(with-config-dir
  (lambda ()
    (let* ((parsed (parse-pi-args '()))
           (info (pi-tui-footer-info parsed))
           (cfg
             (resolve-pi-config parsed
               (list (cons "PI_CODING_AGENT_DIR" (getenv "GF_CONFIG_DIR")))
             ) ;resolve-pi-config
           ) ;cfg
           (job (%worker-job-cfg cfg (list "hello" (list-ref info 2))))
          ) ;
      (check (list-ref info 0) => "deepseek")
      (check (list-ref info 1) => "deepseek-flash")
      (check (list-ref info 2) => "high")
      (check (list-ref info 10) => 1000000)
      (check (pi-cfg-ref job 'provider) => (list-ref info 0))
      (check (pi-cfg-ref job 'model-id) => (list-ref info 1))
      (check (pi-cfg-ref job 'provider-api) => "openai-completions")
    ) ;let*
    ;; 写入不存在的默认模型，强制解析失败；兜底不带模型目录。
    (path-write-text (path->string (path-join (getenv "GF_CONFIG_DIR") "settings.json"))
      "{\"defaultModel\":\"no-such-1413-model\"}"
    ) ;path-write-text
    (let ((info (pi-tui-footer-info (parse-pi-args '()))))
      (check (list-ref info 0) => "deepseek")
      (check (list-ref info 1) => "deepseek-flash")
      (check (list-ref info 2) => "medium")
      (check (list-ref info 6) => '())
    ) ;let
  ) ;lambda
  #t
) ;with-config-dir

(check-report)
