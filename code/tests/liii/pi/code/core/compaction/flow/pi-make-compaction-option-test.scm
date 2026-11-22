;; pi-make-compaction-option
;; 构造自动压缩选项：启用时返回含 compactor 的配置项，未启用时返回 #f。
;;
;; 语法
;; ----
;; (pi-make-compaction-option parsed cfg sfile state timeout . opt-emit)
;;
;; 参数
;; ----
;; parsed : alist
;; 解析后的命令行参数 alist；--no-auto-compact 时禁用自动压缩。
;; cfg : alist
;; 运行配置 alist，含 config-dir（配置文件目录）。
;; sfile : string | #f
;; 会话文件路径；#f 表示无会话文件，不启用自动压缩。
;; state : vector
;; 会话状态向量（元素 0 为消息列表，元素 1 为消息条数）。
;; timeout : number
;; 单轮请求超时时间（秒）。
;; opt-emit : procedure
;; 可选事件回调；压缩完成后以 'compaction 事件通知前端。
;;
;; 返回值
;; ----
;; list | #f
;; 启用时返回 ((compactor . procedure))，否则返回 #f。

(import (scheme base)
  (liii check)
  (liii path)
  (liii pi ai config model-metadata)
  (liii pi ai message)
  (liii pi ai config runtime)
  (liii pi code core compaction flow)
) ;import

(check-set-mode! 'report-failed)

(define CONFIG-DIR (path-join (path-temp-dir) "pi-make-compaction-option-test"))

(define STATE (vector '() 0))

(define (write-settings enabled?)
  (path-mkdir CONFIG-DIR :parents #t :exist-ok #t)
  (path-write-text (path-join CONFIG-DIR (path "settings.json"))
    (string-append "{\"compaction\":{\"enabled\":"
      (if enabled? "true" "false")
      "}}"
    ) ;string-append
  ) ;path-write-text
) ;define

(define CFG (list (cons 'config-dir CONFIG-DIR)))

;; 1. 未启用自动压缩：返回 #f
(write-settings #f)
(check-false (pi-make-compaction-option '() CFG "session.jsonl" STATE 600))

;; 2. 启用自动压缩：返回含 compactor 的配置项
(write-settings #t)
(let ((opt (pi-make-compaction-option '() CFG "session.jsonl" STATE 600)))
  (check-true (pair? opt))
  (check (car (car opt)) => 'compactor)
  (check-true (procedure? (cdr (car opt))))
) ;let

;; 3. 无会话文件时不启用
(check-false (pi-make-compaction-option '() CFG #f STATE 600))

;; 4. --no-auto-compact 时不启用
(check-false (pi-make-compaction-option (list (cons 'no-auto-compact #t))
               CFG
               "session.jsonl"
               STATE
               600
             ) ;pi-make-compaction-option
) ;check-false

;; 5. compactor 执行时重新读取 effective-cfg：安装 prepare-request 钩子后，
;;    运行中切模（窗口从初始值变大）会被 compactor 感知，压缩判定使用新窗口。
;;    这里用过高的阈值保证不实际压缩，仅验证 prepare-request 被调用且窗口读到新值。
(write-settings #t)
(let* ((called (vector 0))
       (eff-cfg
         (list (cons 'config-dir CONFIG-DIR)
           (cons 'provider "google")
           (cons 'model-id "big-model")
           (cons 'model-meta
             (pi-model-metadata "big-model" "big-model" "google" #f 2000000 0)
           ) ;cons
           (cons 'prepare-request
             (lambda (cfg)
               (vector-set! called 0 (+ 1 (vector-ref called 0)))
               ;; 模拟切模后窗口变大
               (pi-cfg-set cfg
                 'model-meta
                 (pi-model-metadata "big-model" "big-model" "google" #f 4000000 0)
               ) ;pi-cfg-set
             ) ;lambda
           ) ;cons
         ) ;list
       ) ;eff-cfg
       (opt (pi-make-compaction-option '() eff-cfg "session.jsonl" STATE 600))
       (compactor (cdr (assoc 'compactor opt)))
       ;; 一条超长但远低于 4M 窗口的消息，不会触发压缩
       (msgs (list (pi-user-message (make-string 1000 #\a))))
       (res (compactor msgs))
      ) ;
  ;; prepare-request 在 compactor 执行时被调用一次
  (check (vector-ref called 0) => 1)
  ;; 未触发压缩：返回原消息列表
  (check (eq? res msgs) => #t)
) ;let*

(check-report)
