;; pi-resolve-request-headers
;; 从模型目录解析自定义 HTTP 请求头，展开环境变量并保留 ${API_KEY} 供请求时解析。
;;
;; 语法
;; ----
;; (pi-resolve-request-headers models-store provider model-id api-key [env])
;;   -> alist
;;
;; 参数
;; ----
;; models-store : alist
;;   provider 与模型目录，形如 (("<provider>" ("models" ...)) ...)。
;; provider : string
;;   要查询的 provider 名称。
;; model-id : string
;;   要查询的模型 id；模型条目缺失时视为未配置 headers。
;; api-key : string | #f
;;   当前 provider 解析出的 API key，用于 ${API_KEY} 占位符。
;; env : alist（可选）
;;   环境变量表，用于插值 ${VAR}；缺省时读取真实环境。
;;
;; 返回值
;; ----
;; alist
;; ((header-name . resolved-value) ...)；未配置 headers 时返回空列表。

(import (liii check)
  (liii pi code config)
) ;import

(check-set-mode! 'report-failed)

(define STORE
  '(("vertex"
     ("api" . "openai-completions")
     ("models"
      (("id" . "plain"))
      (("id" . "custom")
       ("headers"
        ("x-goog-api-key" . "${API_KEY}")
        ("x-tenant" . "tenant-${TENANT_ID}")
        ("x-static" . "static-value"))))))
) ;define

;; 未配置 headers 的模型保持原有空配置。
(check (pi-resolve-request-headers STORE "vertex" "plain" "key") => '())

;; 当前 provider 的 API key 保留为请求模板，环境变量在配置阶段插值。
(let ((headers (pi-resolve-request-headers STORE "vertex" "custom" "secret-key"
                 '(("TENANT_ID" . "42"))
               ) ;pi-resolve-request-headers
      ) ;headers
     ) ;
  (check (cdr (assoc "x-goog-api-key" headers)) => "${API_KEY}")
  (check (cdr (assoc "x-tenant" headers)) => "tenant-42")
  (check (cdr (assoc "x-static" headers)) => "static-value")
) ;let

;; 同一个值支持多个占位符。
(let* ((store '(("p" ("models" (("id" . "m")
                      ("headers" ("x-key" . "${API_KEY}-${SUFFIX}-${API_KEY}")))))))
       (headers (pi-resolve-request-headers store "p" "m" "key" '(("SUFFIX" . "env"))))
      ) ;
  (check (cdr (assoc "x-key" headers)) => "${API_KEY}-env-${API_KEY}")
) ;let*

;; 缺少密钥或环境变量时拒绝启动，不能发送字面量/空认证头。
(check-catch 'pi-config-error
  (pi-resolve-request-headers STORE "vertex" "custom" #f '(("TENANT_ID" . "42")))
) ;check-catch
(check-catch 'pi-config-error
  (pi-resolve-request-headers STORE "vertex" "custom" "secret-key" '())
) ;check-catch

;; 已定义的空环境变量是合法值，可用于拼接可选前后缀。
(let ((headers (pi-resolve-request-headers STORE "vertex" "custom" "secret-key"
                 '(("TENANT_ID" . ""))
               ) ;pi-resolve-request-headers
      ) ;headers
     ) ;
  (check (cdr (assoc "x-tenant" headers)) => "tenant-")
) ;let

;; 非对象 headers 与非字符串值均为配置错误。
(check-catch 'pi-config-error
  (pi-resolve-request-headers
    '(("p" ("models" (("id" . "m") ("headers" . "bad")))))
    "p" "m" "key"
  ) ;pi-resolve-request-headers
) ;check-catch
(check-catch 'pi-config-error
  (pi-resolve-request-headers
    '(("p" ("models" (("id" . "m") ("headers" ("x-key" . 42))))))
    "p" "m" "key"
  ) ;pi-resolve-request-headers
) ;check-catch

(check-report)
