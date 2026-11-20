;; run-pi
;; Pi 命令行入口：剥离命令前缀后分发 install/config/auth/login 与主流程。
;;
;; 语法
;; ----
;; (run-pi raw-args) -> integer?
;;
;; 参数
;; ----
;; raw-args : list?
;; 原始命令行参数字符串列表（含 gf/pi 命令前缀）。
;;
;; 返回值
;; ------
;; integer?
;; 进程退出码：成功为 0，错误为 1。

(import (liii check) (liii string) (liii pi tui cli))

(check-set-mode! 'report-failed)

;; 1. --help：输出帮助并返回 0
(let ((status #f))
  (let ((out
          (with-output-to-string
            (lambda () (set! status (run-pi '("gf" "pi" "--help"))))
          ) ;with-output-to-string
        ) ;out
       ) ;
    (check status => 0)
    (check-true (string-contains? out "Usage:"))
  ) ;let
) ;let

;; 2. 未知子命令前缀走主流程，空消息且无匹配 flow 时回退到帮助（非交互环境），
;;    返回 0
(let ((status #f))
  (with-output-to-string
    (lambda ()
      (with-input-from-string "" (lambda () (set! status (run-pi '("gf" "pi")))))
    ) ;lambda
  ) ;with-output-to-string
  (check status => 0)
) ;let

;; 3. 错误被 catch 兜住，返回退出码 1（构造需要 --model 的 --provider 错误）
(let ((status #f))
  (let ((err
          (let ((p (open-output-string)))
            (define (capture-thunk)
              (let ((orig *stderr*))
                (dynamic-wind (lambda () (set! *stderr* p))
                  (lambda () (set! status (run-pi '("gf" "pi" "--provider"
                                                    "google"))))
                  (lambda () (set! *stderr* orig))
                ) ;dynamic-wind
              ) ;let
            ) ;define
            (capture-thunk)
            (get-output-string p)
          ) ;let
        ) ;err
       ) ;
    (check status => 1)
  ) ;let
) ;let

(check-report)
