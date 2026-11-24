;; pi-user-provider-model-list
;; 返回配置视图使用的完整模型列表，可用模型在前并带 enabled 标记。
;;
;; 语法
;; ----
;; (pi-user-provider-model-list config-dir p-id)
;;
;; 参数
;; ----
;; config-dir : string
;; 用户配置目录。
;; p-id : string
;; provider id。
;;
;; 返回值
;; ----
;; list
;; 带有 enabled 标记的模型 alist 列表。

(import (liii check)
  (liii string)
  (liii list)
  (liii pi code config user-models)
) ;import

(check-set-mode! 'report-failed)

(define FIXTURE
  (if (file-exists? "tools/pi/tests/fixtures/user-config")
    "tools/pi/tests/fixtures/user-config"
    "tests/fixtures/user-config"
  ) ;if
) ;define

(let* ((models (pi-user-provider-model-list (string-append FIXTURE "/full") "kimi-coding")
       ) ;models
       (first (car models))
      ) ;
  (check (pair? models) => #t)
  (check (cdr (assoc "id" first)) => "k3.1-pro")
  (check (cdr (assoc "enabled" first)) => #t)
  ;; 白名单外的内置模型以 enabled #f 出现在后面
  (check (cdr (assoc "enabled" (list-ref models 1))) => #f)
) ;let*

;; 含斜杠 id 的模型文件位于子目录（models/<p>/<org>/<model>.json）：
;; 白名单模式应合成全部 3 个模型且均激活
(let* ((models (pi-user-provider-model-list (string-append FIXTURE "/slash-ids") "google")
       ) ;models
       (by-id
         (lambda (id) (find (lambda (m) (string=? (cdr (assoc "id" m)) id)) models))
       ) ;by-id
       (glm (by-id "zai-org/glm-5.2-maas"))
       (ds (by-id "deepseek-ai/deepseek-v4.1-flash-1017-maas"))
       (g38 (by-id "gemini-3.8-flash"))
      ) ;
  ;; 三个模型都在列表中
  (check (and glm #t) => #t)
  (check (and ds #t) => #t)
  (check (and g38 #t) => #t)
  ;; 均激活，字段完整
  (check (cdr (assoc "enabled" glm)) => #t)
  (check (cdr (assoc "name" glm)) => "GLM 5.2")
  (check (cdr (assoc "enabled" ds)) => #t)
  (check (cdr (assoc "name" ds)) => "DeepSeek V4 Flash")
  (check (cdr (assoc "enabled" g38)) => #t)
) ;let*

;; 被禁用（从白名单移除）的含斜杠 id 模型仍以未激活项出现，字段不丢失：
;; models/<p>/<org>/<model>.json 子目录里的文件必须能被目录枚举发现
(let* ((models (pi-user-provider-model-list (string-append FIXTURE "/slash-ids-disabled")
                 "google"
               ) ;pi-user-provider-model-list
       ) ;models
       (by-id
         (lambda (id) (find (lambda (m) (string=? (cdr (assoc "id" m)) id)) models))
       ) ;by-id
       (glm (by-id "zai-org/glm-5.2-maas"))
       (ds (by-id "deepseek-ai/deepseek-v4.1-flash-1017-maas"))
       (g38 (by-id "gemini-3.8-flash"))
      ) ;
  ;; glm 不在白名单，但模型文件在子目录里，必须仍出现在列表（灰显未激活）
  (check (and glm #t) => #t)
  (check (cdr (assoc "enabled" glm)) => #f)
  (check (cdr (assoc "name" glm)) => "GLM 5.2")
  (check (cdr (assoc "contextWindow" glm)) => 1000000)
  ;; 白名单内模型仍激活
  (check (cdr (assoc "enabled" g38)) => #t)
  (check (cdr (assoc "enabled" ds)) => #t)
) ;let*

(check-report)
