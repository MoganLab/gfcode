;; display-message-line
;; 输出消息的一行：本条消息的首行带 💬 前缀，续行直接输出。
;;
;; 语法
;; ----
;; (display-message-line turn-box line port)
;;
;; 参数
;; ----
;; turn-box : pair?
;; 含 (轮次 消息缓冲 是否已打印过本条消息首行 ...) 的可变列表。
;;
;; line : string
;; 待输出的一行文本。
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

;; 1. 首行（未打印过本条消息）带 💬 前缀
(let* ((tb (list 0 "x" #f))
       (out
         (with-output-to-string (lambda () (display-message-line tb "hi" (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "💬 hi\n")
) ;let*

;; 2. 续行（已打印过首行）不带前缀
(let* ((tb (list 0 "x" #t))
       (out
         (with-output-to-string (lambda () (display-message-line tb "next" (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "next\n")
) ;let*

;; 3. 空行内容仍输出前缀与换行
(let* ((tb (list 0 "x" #f))
       (out
         (with-output-to-string (lambda () (display-message-line tb "" (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "💬 \n")
) ;let*

(check-report)
