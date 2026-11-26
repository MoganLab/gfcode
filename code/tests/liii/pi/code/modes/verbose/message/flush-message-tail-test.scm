;; flush-message-tail
;; message 结束时打印剩余未换行的尾部，并复位消息缓冲与首行标记。
;;
;; 语法
;; ----
;; (flush-message-tail turn-box port)
;;
;; 参数
;; ----
;; turn-box : pair?
;; 含 (轮次 消息缓冲 是否已打印过本条消息首行 ...) 的可变列表。
;;
;; port : output-port?
;; 输出端口。
;;
;; 返回值
;; ----
;; unspecified

(import (scheme base)
  (liii check)
  (liii string)
  (liii pi code modes verbose message)
) ;import

(check-set-mode! 'report-failed)

;; 1. 缓冲有尾部文本时输出并复位
(let* ((tb (list 0 "尾行" #t))
       (out
         (with-output-to-string (lambda () (flush-message-tail tb (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "尾行\n")
  (check (cadr tb) => "")
  (check (caddr tb) => #f)
) ;let*

;; 2. 缓冲为空时不输出，仍复位标记
(let* ((tb (list 0 "" #t))
       (out
         (with-output-to-string (lambda () (flush-message-tail tb (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "")
  (check (cadr tb) => "")
  (check (caddr tb) => #f)
) ;let*

;; 3. 缓冲仅含空白时裁剪后不输出
(let* ((tb (list 0 "  \n  " #f))
       (out
         (with-output-to-string (lambda () (flush-message-tail tb (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "")
  (check (cadr tb) => "")
  (check (caddr tb) => #f)
) ;let*

(check-report)
