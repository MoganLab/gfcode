;; flush-message-lines
;; 合并消息缓冲增量后，遇到 \n 就立即打印完整行，并更新缓冲与首行标记。
;;
;; 语法
;; ----
;; (flush-message-lines turn-box port)
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

;; 1. 缓冲含多行时逐行打印，首行带前缀，续行不带
(let* ((tb (list 0 "第一行\n第二行\n" #f))
       (out
         (with-output-to-string (lambda () (flush-message-lines tb (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "💬 第一行\n第二行\n")
  (check (cadr tb) => "")
  (check (caddr tb) => #t)
) ;let*

;; 2. 缓冲无换行时不输出，保留缓冲
(let* ((tb (list 0 "不完整行" #f))
       (out
         (with-output-to-string (lambda () (flush-message-lines tb (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "")
  (check (cadr tb) => "不完整行")
  (check (caddr tb) => #f)
) ;let*

;; 3. 缓冲仅余换行后尾部时输出已缓冲行，尾部保留
(let* ((tb (list 0 "已缓冲\n尾部" #f))
       (out
         (with-output-to-string (lambda () (flush-message-lines tb (current-output-port)))
         ) ;with-output-to-string
       ) ;out
      ) ;
  (check out => "💬 已缓冲\n")
  (check (cadr tb) => "尾部")
  (check (caddr tb) => #t)
) ;let*

(check-report)
