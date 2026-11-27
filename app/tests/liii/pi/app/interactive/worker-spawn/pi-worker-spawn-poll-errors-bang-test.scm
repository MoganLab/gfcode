;; pi-worker-spawn-poll-errors!
;; 轮询后台 worker 的启动结果，把普通 go 只能写 stderr 的前导 import 错误
;; 写入 pi 日志。worker 函数尚未执行，因此其函数体内的 catch 无法处理此类错误。
;;
;; 语法
;; ----
;; (pi-worker-spawn-poll-errors!)
;;
;; 参数
;; ----
;; 无
;;
;; 返回值
;; ----
;; unspecified
;; 只轮询已完成结果，不阻塞长期运行的 worker。
;; 成功结果仅移除记录；error 结果追加 worker-error name=... 日志。
;; 日志写盘失败静默忽略，不影响 TUI 事件循环。

(import (scheme base)
  (liii check)
  (liii go)
  (liii path)
  (liii shutil)
  (liii string)
  (liii tempfile)
  (liii time)
  (liii pi ai log)
  (liii pi app interactive worker-spawn)
) ;import

(check-set-mode! 'report-failed)

(define *base* (make-temp-dir "gf-pi-worker-spawn-" ""))
(define *log-dir* (path-join (path *base*) "logs"))
(pi-log-init! *log-dir*)

(define (%log-text)
  (let ((file (pi-log-file-path)))
    (if (file-exists? (path->string file)) (path-read-text file) "")
  ) ;let
) ;define

(define (%poll-until-log)
  (let loop
    ((i 0))
    (cond ((string-contains? (%log-text) "worker-error") #t)
          ((= i 100) #f)
          (else (pi-worker-spawn-poll-errors!) (sleep 0.05) (loop (+ i 1)))
    ) ;cond
  ) ;let
) ;define

;; 前导 import 在 worker 中会重新查找已经加载过的库；主会话则会命中缓存。
;; 删除源目录可以可靠地制造仅 worker 可见的导入失败。
(define (%register-broken-library!)
  (let* ((root (path-join (path *base*) "broken-root"))
         (dir (path-join root "gfcode"))
         (file (path-join dir "gone.scm"))
        ) ;
    (path-mkdir dir :parents #t :exist-ok #t)
    (path-write-text file
      "(define-library (gfcode gone) (import (scheme base)) (export ok) (begin (define ok #t)))"
    ) ;path-write-text
    (set! *load-path* (cons (path->string root) *load-path*))
    (eval '(import (gfcode gone)) (rootlet))
    (rmtree (path->string root) #t)
  ) ;let*
) ;define

;; 正常 worker 仍能执行；完成前重复轮询不会丢失结果记录。
;; 成功路径必须先执行：失败用例留下的失效库会被后续 worker 前导重放。
(define (%ok-worker ch)
  (chan-send! ch 'ok 1000)
) ;define

(let ((output (make-chan 1)))
  (%pi-worker-spawn! "display" %ok-worker output)
  (pi-worker-spawn-poll-errors!)
  (pi-worker-spawn-poll-errors!)
  (check (chan-recv! output 5000 #f) => 'ok)
  (let loop
    ((i 0))
    (when (< i 100)
      (pi-worker-spawn-poll-errors!)
      (sleep 0.01)
      (loop (+ i 1))
    ) ;when
  ) ;let
  (check (string-contains? (%log-text) "worker-error name=display") => #f)
) ;let

;; 失败发生在目标函数执行前：日志可见且结果 channel 不收到正常任务输出。
(define (%failed-worker ch)
  (chan-send! ch 'unexpected 1000)
) ;define

(let ((output (make-chan 1)))
  (%register-broken-library!)
  (%pi-worker-spawn! "agent" %failed-worker output)
  (check-true (%poll-until-log))
  (check-true (string-contains? (%log-text) "worker-error name=agent"))
  (check-true (string-contains? (%log-text) "io-error"))
  (check-true (string-contains? (%log-text) "gfcode/gone.scm"))
  (check (chan-try-recv! output #f) => #f)
) ;let

(pi-log-reset!)
(rmtree *base* #t)

(check-report)
