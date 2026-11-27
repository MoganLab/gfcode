;; pi-worker-handle-job
;; extension_command 分支与普通任务同样 arm abort 通道：
;; 排空残留信号并复位中止标志，保证扩展会话可被 ESC 中止、
;; 且不受上一任务残留 aborted 标志的误伤。
;;
;; 语法
;; ----
;; (pi-worker-handle-job job parsed cfg sfile-box event-chan abort-chan)
;;
;; 参数
;; ----
;; job : pair?
;; (extension_command name args) 形式的任务。
;; parsed : alist?
;; worker CLI 参数。
;; cfg : alist?
;; worker 运行配置。
;; sfile-box : vector?
;; 会话文件盒。
;; event-chan : chan?
;; TUI 事件通道。
;; abort-chan : chan?
;; ESC 中止信号通道。
;;
;; 返回值
;; ----
;; alist?
;; 本 job 结算后的 effective-cfg。
;; 处理 extension_command 后 pi-aborted? 恢复为 #f（标志已复位），
;; abort-chan 中预置的残留信号被排空。

(import (scheme base)
  (liii check)
  (liii go)
  (liii path)
  (liii pi ai abort)
  (liii pi code core extensions)
  (liii pi code core extension-result)
  (liii pi app interactive worker)
) ;import

(check-set-mode! 'report-failed)

;; 预置脏状态：上一任务被中止（*aborted?* 已置位）+ 通道残留信号。
;; 若 extension_command 分支漏 arm，残留标志会让后续会话瞬间误判 aborted。
(let* ((registry (make-extension-registry))
       (jobs-abort (make-chan 4))
       (ev-chan (make-chan 16))
       (command (make-extension-command-def "/arm-probe"
                  "probe"
                  (lambda (args ctx) (make-review-no-files "nothing" #f))
                ) ;make-extension-command-def
       ) ;command
      ) ;
  (register-command! registry command)
  (set-default-extension-registry! registry)
  ;; 模拟上一任务的中止现场：arm 后收到信号并消费置位
  (pi-abort-arm-chan! jobs-abort)
  (chan-send! jobs-abort 'abort 0)
  (check-true (pi-aborted?))
  ;; 再塞一条残留信号：arm 应将其排空，不误伤本任务
  (chan-send! jobs-abort 'abort 0)
  (pi-worker-handle-job (list 'extension_command "/arm-probe" "")
    '()
    (list (cons 'config-dir (path->string (path-temp-dir)))
      (cons 'agent-dir (path->string (path-temp-dir)))
    ) ;list
    (vector #f)
    ev-chan
    jobs-abort
  ) ;pi-worker-handle-job
  ;; 中止标志已复位：扩展会话不会被残留 aborted 标志瞬间误结算
  (check-false (pi-aborted?))
  ;; 残留信号已被排空：不会在会话中途才被消费
  (check (chan-try-recv! jobs-abort #f) => #f)
  ;; 命令正常执行并结算（notice + agent_settled）
  (check (car (chan-try-recv! ev-chan #f)) => 'extension_command_notice)
  ;; ESC 中止链路可用：新信号可被 pi-aborted? 感知
  (chan-send! jobs-abort 'abort 0)
  (check-true (pi-aborted?))
  (pi-abort-reset!)
  (set-default-extension-registry! #f)
) ;let*

(check-report)
