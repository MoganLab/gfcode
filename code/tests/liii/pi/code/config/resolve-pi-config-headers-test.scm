;; resolve-pi-config headers 集成
;; provider/model 两级 headers 合并、凭据插值与 CLI 配置注入。
;;
;; 语法
;; ----
;; (resolve-pi-config parsed-args [env]) -> pi-config
;;
;; 参数
;; ----
;; parsed-args : pi-args
;;   经 parse-pi-args 解析的命令行参数（含 --provider/--model）。
;; env : alist（可选）
;;   环境变量表；测试用它定位临时配置目录并注入 TENANT_ID。
;;
;; 返回值
;; ----
;; pi-config
;;   含 'headers 字段的配置记录，headers 为 provider/model 合并后的 alist。

(import (scheme base)
  (scheme file)
  (liii check)
  (liii path)
  (liii shutil)
  (liii pi code cli args)
  (liii pi code config)
) ;import

(check-set-mode! 'report-failed)

(define TMP-DIR
  (path->string (path-join (path-temp-dir) "pi-resolve-config-headers-test"))
) ;define

(when (file-exists? TMP-DIR)
  (rmtree TMP-DIR #t)
) ;when
(path-mkdir (path-join (path TMP-DIR) (path "models") (path "vertex"))
  :parents #t :exist-ok #t
) ;path-mkdir

(path-write-text (path->string (path-join (path TMP-DIR) (path "models/providers.json")))
  "[\"vertex\"]"
) ;path-write-text
(path-write-text (path->string (path-join (path TMP-DIR) (path "models/vertex.json")))
  "{\"baseUrl\":\"https://example.com/v1\",\"api\":\"openai\",\"models\":[\"m\"],\"headers\":{\"x-goog-api-key\":\"${API_KEY}\",\"x-shared\":\"provider\",\"x-tenant\":\"tenant-${TENANT_ID}\"}}"
) ;path-write-text
(path-write-text (path->string (path-join (path TMP-DIR) (path "models/vertex/m.json")))
  "{\"id\":\"m\",\"contextWindow\":1024,\"maxTokens\":128,\"headers\":{\"X-Shared\":\"model\"}}"
) ;path-write-text
(path-write-text (path->string (path-join (path TMP-DIR) (path "auth.json")))
  "{\"vertex\":{\"type\":\"api_key\",\"key\":\"fixture-key\"}}"
) ;path-write-text

(let* ((args (parse-pi-args '("--provider" "vertex" "--model" "m")))
       (env (list (cons "PI_CODING_AGENT_DIR" TMP-DIR)
              (cons "TENANT_ID" "42")
            ) ;list
       ) ;env
       (cfg (resolve-pi-config args env))
       (headers (pi-cfg-ref cfg 'headers))
      ) ;
  (check (pi-cfg-ref cfg 'provider-api) => "openai-completions")
  (check (cdr (assoc "x-goog-api-key" headers)) => "${API_KEY}")
  (check (cdr (assoc "x-tenant" headers)) => "tenant-42")
  ;; HTTP header 名大小写不敏感：模型级覆盖 provider 级同名项。
  (check (cdr (assoc "X-Shared" headers)) => "model")
  (check (assoc "x-shared" headers) => #f)
) ;let*

(rmtree TMP-DIR #t)

(check-report)
