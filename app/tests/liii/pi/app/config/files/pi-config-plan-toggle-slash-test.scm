;; pi-config-plan-toggle-slash
;; 含斜杠 id 的模型文件（位于子目录 models/<p>/<org>/<model>.json）启停：
;; 空格禁用把目标字符串从供应商文件 models 数组移除，落盘重载后该模型仍以
;; 未激活项出现在配置视图（不从列表消失）；再次启用可恢复，往返不丢字段、
;; 不产生重复。覆盖 model-files.scm 的 %directory-model-ids 递归扫描子目录。
;;
;; 语法
;; ----
;; (pi-config-plan-toggle st cursor . opt-column)
;;
;; 参数
;; ----
;; st : pi-config-state
;; 配置 TUI 的只读视图模型。
;; cursor : alist
;; provider 与模型光标位置。
;; opt-column : integer
;; 0 表示 provider 列，1 表示模型列。
;;
;; 返回值
;; ----
;; alist
;; 包含 ok、message 与 writes 的写入计划。

(import (scheme base)
  (liii check)
  (liii list)
  (liii string)
  (liii path)
  (liii os)
  (liii path stat)
  (scheme time)
  (liii json)
  (liii pi app config state)
  (liii pi app config layout)
  (liii pi app config files)
  (liii pi app config json-write)
) ;import

(check-set-mode! 'report-failed)

(define FIXTURE
  (if (file-exists? "tools/pi/tests/fixtures/user-config")
    "tools/pi/tests/fixtures/user-config"
    "tests/fixtures/user-config"
  ) ;if
) ;define

(define (ref alist key)
  (let ((pair (assoc key alist)))
    (and pair (cdr pair))
  ) ;let
) ;define

(define (p-index st id)
  (list-index (lambda (p) (string=? (pi-config-provider-id p) id))
    (pi-config-state-providers st)
  ) ;list-index
) ;define

(define (m-index st p-id m-id)
  (let* ((p (pi-config-provider st p-id)) (models (pi-config-provider-models p)))
    (list-index (lambda (m) (string=? (pi-config-model-id m) m-id)) models)
  ) ;let*
) ;define

(define (wtext plan rel)
  (let ((pair (assoc rel (ref plan "writes"))))
    (and pair (cdr pair))
  ) ;let
) ;define

(define %dir-counter 0)

;; 复制任意子夹具（如 slash-ids）到独立临时目录，避免相互污染

(define (make-dir-from name sub)
  (set! %dir-counter (+ %dir-counter 1))
  (let* ((src (path-join (path FIXTURE) (path sub)))
         (dst
           (path-join (path-temp-dir)
             (string-append "pi-config-slash-"
               name
               "-"
               (number->string (current-second))
               "-"
               (number->string %dir-counter)
             ) ;string-append
           ) ;path-join
         ) ;dst
        ) ;
    (define (copy-tree s d)
      (unless (path-exists? d)
        (path-mkdir d :parents #t :exist-ok #t)
      ) ;unless
      (for-each
        (lambda (entry)
          (let ((sp (path-join s (path entry))) (dp (path-join d (path entry))))
            (if (path-stat-dir? (path-stat (path->string sp)))
              (copy-tree sp dp)
              (path-copy sp dp)
            ) ;if
          ) ;let
        ) ;lambda
        (vector->list (listdir (path->string s)))
      ) ;for-each
    ) ;define
    (copy-tree src dst)
    dst
  ) ;let*
) ;define

;; 1. 禁用含斜杠 id 的模型：供应商文件 models 数组只移除目标字符串，
;; 其余项保留；落盘重载后该模型仍以未激活项出现（不从配置列表消失）
(let* ((dir (make-dir-from "disable" "slash-ids"))
       (st (pi-config-state (path->string dir) :env '()))
       (cursor (pi-config-cursor (p-index st "google")
                 (m-index st "google" "zai-org/glm-5.2-maas")
               ) ;pi-config-cursor
       ) ;cursor
       (plan (pi-config-plan-toggle st cursor 1))
       (writes (ref plan "writes"))
      ) ;
  (check (ref plan "ok") => #t)
  ;; 供应商文件：移除 glm，保留 gemini-3.8-flash 与 deepseek
  (let ((text (wtext plan "models/google.json")))
    (check (string-contains text "gemini-3.8-flash") => #t)
    (check (string-contains text "deepseek-ai") => #t)
    (check (string-contains text "zai-org/glm-5.2-maas") => #f)
  ) ;let
  ;; 落盘
  (check (ref (pi-config-apply-writes st writes) "ok") => #t)
  ;; 重载：glm 仍在列表（未激活），其它模型仍激活，字段完整
  (let* ((st2 (pi-config-state (path->string dir) :env '()))
         (models (pi-config-provider-models (pi-config-provider st2 "google")))
         (by-id
           (lambda (id) (find (lambda (m) (string=? (pi-config-model-id m) id)) models))
         ) ;by-id
         (glm (by-id "zai-org/glm-5.2-maas"))
        ) ;
    (check (and glm #t) => #t)
    (check (pi-config-model-enabled? glm) => #f)
    (check (pi-config-model-name glm) => "GLM 5.2")
    (check (pi-config-model-enabled? (by-id "gemini-3.8-flash")) => #t)
    (check (pi-config-model-enabled? (by-id "deepseek-ai/deepseek-v4.1-flash-1017-maas"))
      =>
      #t
    ) ;check
  ) ;let*
) ;let*

;; 2. 被禁用的含斜杠 id 模型可再次启用：白名单恢复，定义不丢失
(let* ((dir (make-dir-from "reenable" "slash-ids"))
       (st (pi-config-state (path->string dir) :env '()))
       (cursor1 (pi-config-cursor (p-index st "google")
                  (m-index st "google" "zai-org/glm-5.2-maas")
                ) ;pi-config-cursor
       ) ;cursor1
       (plan1 (pi-config-plan-toggle st cursor1 1))
       (_1 (pi-config-apply-writes st (ref plan1 "writes")))
       (st2 (pi-config-state (path->string dir) :env '()))
       (cursor2 (pi-config-cursor (p-index st2 "google")
                  (m-index st2 "google" "zai-org/glm-5.2-maas")
                ) ;pi-config-cursor
       ) ;cursor2
       (plan2 (pi-config-plan-toggle st2 cursor2 1))
       (text (wtext plan2 "models/google.json"))
       (_2 (pi-config-apply-writes st2 (ref plan2 "writes")))
       (st3 (pi-config-state (path->string dir) :env '()))
       (models (pi-config-provider-models (pi-config-provider st3 "google")))
       (by-id
         (lambda (id) (find (lambda (m) (string=? (pi-config-model-id m) id)) models))
       ) ;by-id
       (glm (by-id "zai-org/glm-5.2-maas"))
      ) ;
  (check (ref plan2 "ok") => #t)
  ;; 白名单重新包含三个模型（JSON 中 / 被转义为 \/，用 zai-org 片段断言）
  (check (string-contains text "zai-org") => #t)
  (check (pi-config-model-enabled? glm) => #t)
  (check (pi-config-model-name glm) => "GLM 5.2")
  ;; 不产生重复 glm
  (check
    (length
      (filter (lambda (m) (string=? (pi-config-model-id m) "zai-org/glm-5.2-maas"))
        models
      ) ;filter
    ) ;length
    =>
    1
  ) ;check
) ;let*

(check-report)
