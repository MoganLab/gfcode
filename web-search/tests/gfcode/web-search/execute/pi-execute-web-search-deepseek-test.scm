;; pi-execute-web-search-deepseek
;; 验证 pi-execute-web-search 在 deepseek provider 分支下的搜索与抓取行为。
;;
;; 语法
;; ----
;; (pi-execute-web-search args . opts)
;;
;; 参数
;; ----
;; args : list?
;; web_search 工具参数 alist。
;;
;; opts : list?
;; 可选关键字参数，支持 :api-key、:provider、:config 等。
;;
;; 返回值
;; ----
;; list?
;; 包含 text、content 与 sources 字段的搜索结果 alist。

(import (scheme base)
  (liii check)
  (liii string)
  (liii subprocess)
  (liii pi code core extensions)
  (gfcode web-search execute)
  (gfcode web-search config)
  (liii pi code core tools)
) ;import

(check-set-mode! 'report-failed)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; e2e 测试（stub server）
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define (find-web-search-fixture)
  (let loop
    ((candidates '("tools/pi/tests/fixtures/web-search.json"
                   "tests/fixtures/web-search.json" "fixtures/web-search.json"
                   "../fixtures/web-search.json"
                   "../../fixtures/web-search.json"
                   "../../../fixtures/web-search.json"
                   "../../../../tools/pi/tests/fixtures/web-search.json")
     ) ;candidates
    ) ;
    (cond ((null? candidates) (error 'file-not-found "web-search.json fixture not found"))
          ((file-exists? (car candidates)) (car candidates))
          (else (loop (cdr candidates)))
    ) ;cond
  ) ;let
) ;define

(define (find-stub-server)
  (let loop
    ((candidates '("tools/pi/tests/stub_deepseek_server.py"
                   "tests/stub_deepseek_server.py" "stub_deepseek_server.py"
                   "../stub_deepseek_server.py" "../../stub_deepseek_server.py"
                   "../../../stub_deepseek_server.py"
                   "../../../../tools/pi/tests/stub_deepseek_server.py"
                   "../../../../../tools/pi/tests/stub_deepseek_server.py")
     ) ;candidates
    ) ;
    (cond ((null? candidates) (error 'file-not-found "stub_deepseek_server.py not found"))
          ((file-exists? (car candidates)) (car candidates))
          (else (loop (cdr candidates)))
    ) ;cond
  ) ;let
) ;define

(define (parse-port-line line)
  (if (and (string? line) (string-starts? line "PORT:"))
    (string->number (substring line 5 (string-length line)))
    #f
  ) ;if
) ;define

;; 隔离环境：web-search.json / HOME / 配置目录均指向不存在的路径，
;; 确保默认请求不受开发者本机真实全局配置干扰。

(define (isolated-env)
  (list (cons "PI_WEB_SEARCH_CONFIG" "/nonexistent-gf-test/ws.json")
    (cons "HOME" "/nonexistent-gf-test")
    (cons "PI_CODING_AGENT_DIR" "/nonexistent-gf-test")
  ) ;list
) ;define

(let* ((proc (process-spawn (list "python3" (find-stub-server)) :stdout 'pipe))
       (port (parse-port-line (process-read-line proc)))
       (base-url (string-append "http://127.0.0.1:" (number->string port)))
      ) ;
  (check-true (number? port))

  ;; 5.1 正常搜索：显式 :provider "deepseek"
  (let ((res (pi-execute-web-search '(("query" . "goldfish scheme"))
               :provider "deepseek"
               :api-key  "ds-test-key"
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (let ((txt (cdr (assoc 'text res))))
      (check-true (string-contains? txt "Goldfish Official"))
      (check-true (string-contains? txt "https://goldfish.liii.pro"))
      (check-true (string-contains? txt "## Sources"))
    ) ;let
    (check (length (cdr (assoc 'sources res))) => 2)
    ;; 默认模型标识为 deepseek-flash，不再出现 deepseek-search
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let

  ;; 5.2 通过 config 的 provider 自动分发（不带 :provider opt）
  ;; 注意：web-search.json 是全局覆盖，优先级高于 config 的 provider，
  ;;      因此用 :env 指向不存在的路径隔离开发者本机的真实全局配置
  (let ((res (pi-execute-web-search '(("query" . "goldfish scheme"))
               :config   '((provider . "deepseek") (api-key . "ds-test-key"))
               :env      (isolated-env)
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (let ((txt (cdr (assoc 'text res))))
      (check-true (string-contains? txt "Goldfish Official"))
    ) ;let
  ) ;let

  ;; 5.2b web-search.json 全局覆盖：会话 provider 是别的，也走配置的 deepseek
  (let ((res
          (pi-execute-web-search '(("query" . "goldfish scheme"))
            :config '((provider . "kimi-coding"))
            :env
            (list (cons "PI_WEB_SEARCH_CONFIG" (find-web-search-fixture))
              (cons "HOME" "/nonexistent-gf-test")
              (cons "PI_CODING_AGENT_DIR" "/nonexistent-gf-test")
            ) ;list
            :api-key  "ds-test-key"
            :base-url base-url
            :timeout  10
          ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (let ((txt (cdr (assoc 'text res))))
      (check-true (string-contains? txt "Goldfish Official"))
    ) ;let
  ) ;let

  ;; 5.2c 空配置默认命中 DeepSeek stub：不传 :provider/:model，不设置环境变量，
  ;;      web-search.json 也指向不存在的路径，证明默认请求确实到 DeepSeek，
  ;;      不进入 Gemini 分支，也不要求 GOOGLE_API_KEY。
  (let ((res (pi-execute-web-search '(("query" . "goldfish scheme"))
               :config   '()
               :env      (isolated-env)
               :api-key  "ds-test-key"
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (let ((txt (cdr (assoc 'text res))))
      (check-true (string-contains? txt "Goldfish Official"))
    ) ;let
    ;; 默认模型标识为 deepseek-flash
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let

  ;; 5.3 空配置缺省 provider 已为 deepseek（google 场景由
  ;;     pi-web-search-execute-test.scm 显式 :provider "google" 覆盖）
  (check (pi-resolve-web-search-provider '() #f #f) => "deepseek")

  ;; 5.4 带 urls：deepseek 分支用 fetch API 读取页面
  (let ((res (pi-execute-web-search '(("query" . "goldfish scheme")
                                      ("urls" "https://example.com/page1"))
               :provider "deepseek"
               :api-key  "ds-test-key"
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (check-true (string-contains? (cdr (assoc 'text res)) "Example Page"))
    ;; 带 urls 时结果模型标识仍为 deepseek-flash
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let

  ;; 5.5 HTTP 401 鉴权失败
  (check-catch 'error
    (pi-execute-web-search '(("query" . "goldfish scheme"))
      :provider "deepseek"
      :api-key  "bad-key"
      :base-url base-url
      :timeout  10
    ) ;pi-execute-web-search
  ) ;check-catch

  ;; 5.6 HTTP 500 服务端错误
  (check-catch 'error
    (pi-execute-web-search '(("query" . "error-500"))
      :provider "deepseek"
      :api-key  "ds-test-key"
      :base-url base-url
      :timeout  10
    ) ;pi-execute-web-search
  ) ;check-catch

  ;; 5.7 空结果
  (let ((res (pi-execute-web-search '(("query" . "empty results"))
               :provider "deepseek"
               :api-key  "ds-test-key"
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (check-true (string-contains? (cdr (assoc 'text res)) "No search results"))
    ;; 空结果的模型标识也为 deepseek-flash
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let

  ;; 5.8 超时
  (check-catch 'error
    (pi-execute-web-search '(("query" . "slow search"))
      :provider "deepseek"
      :api-key  "ds-test-key"
      :base-url base-url
      :timeout  1
    ) ;pi-execute-web-search
  ) ;check-catch

  ;; 5.9 通过 execute-tool-call 分发（web_search 为扩展工具，需在注册表内分发）
  (let* ((api (make-extension-api))
         (_ (pi-load-extension (if (file-exists? "gfcode/web-search/index.scm")
                                 "gfcode/web-search/index.scm"
                                 "../gfcode/web-search/index.scm"
                               ) ;if
              api
            ) ;pi-load-extension
         ) ;_
         (call-res
           (with-extension-registry api
             (lambda ()
               (execute-tool-call "web_search"
                 '(("query" . "goldfish scheme"))
                 :provider "deepseek"
                 :api-key  "ds-test-key"
                 :base-url base-url
                 :timeout  10
               ) ;execute-tool-call
             ) ;lambda
           ) ;with-extension-registry
         ) ;call-res
        ) ;
    (check-false (cdr (assoc 'isError call-res)))
    (check-true (string-contains? (cdr (assoc 'text call-res)) "Goldfish Official"))
    (check
      (cdr (assoc 'model (cdr (assoc 'details call-res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let*

  ;; 5.10 通过 execute-tool-call 分发且完全不传 provider/model：证明默认请求
  ;;      确实到 DeepSeek stub，而不只验证一个孤立的默认值函数
  (let* ((api (make-extension-api))
         (_ (pi-load-extension (if (file-exists? "gfcode/web-search/index.scm")
                                 "gfcode/web-search/index.scm"
                                 "../gfcode/web-search/index.scm"
                               ) ;if
              api
            ) ;pi-load-extension
         ) ;_
         (call-res
           (with-extension-registry api
             (lambda ()
               (execute-tool-call "web_search"
                 '(("query" . "goldfish scheme"))
                 :config   '()
                 :env      (isolated-env)
                 :api-key  "ds-test-key"
                 :base-url base-url
                 :timeout  10
               ) ;execute-tool-call
             ) ;lambda
           ) ;with-extension-registry
         ) ;call-res
        ) ;
    (check-false (cdr (assoc 'isError call-res)))
    (check-true (string-contains? (cdr (assoc 'text call-res)) "Goldfish Official"))
    (check
      (cdr (assoc 'model (cdr (assoc 'details call-res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let*

  ;; 5.11 web-search.json 显式 model=deepseek-flash 透传到 details.model
  (let ((res
          (pi-execute-web-search '(("query" . "goldfish scheme"))
            :provider "deepseek"
            :env
            (list (cons "PI_WEB_SEARCH_CONFIG" (find-web-search-fixture))
              (cons "HOME" "/nonexistent-gf-test")
              (cons "PI_CODING_AGENT_DIR" "/nonexistent-gf-test")
            ) ;list
            :api-key  "ds-test-key"
            :base-url base-url
            :timeout  10
          ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let

  ;; 5.12 显式 :model-id 原样进入 details.model（不被默认值覆盖）
  (let ((res (pi-execute-web-search '(("query" . "goldfish scheme"))
               :provider "deepseek"
               :model-id "deepseek-custom"
               :api-key  "ds-test-key"
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-custom"
    ) ;check
  ) ;let

  ;; 5.13 跨 provider 隔离：会话是 google/gemini-3.8-flash，但显式选择 deepseek，
  ;;      搜索模型使用 deepseek-flash，不串用 Gemini 模型 id
  (let ((res (pi-execute-web-search '(("query" . "goldfish scheme"))
               :provider "deepseek"
               :config  '((provider . "google") (model-id . "gemini-3.8-flash"))
               :env     (isolated-env)
               :api-key "ds-test-key"
               :base-url base-url
               :timeout  10
             ) ;pi-execute-web-search
        ) ;res
       ) ;
    (check-false (cdr (assoc 'isError res)))
    (check
      (cdr (assoc 'model (cdr (assoc 'details res))))
      =>
      "deepseek-flash"
    ) ;check
  ) ;let

  (process-kill proc)
  (process-wait proc)
) ;let*

(check-report)
