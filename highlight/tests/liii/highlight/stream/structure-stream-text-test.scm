;; structure-stream-text
;; 获取结构流已交付原文的总拼接。
;;
;; 语法
;; ----
;; (structure-stream-text stream)
;;
;; 参数
;; ----
;; stream : structure-stream?
;;
;; 返回值
;; -----
;; string
;; 顶层 content 与最外层 close 文本的拼接；嵌套 close 不重复计数。
;; 任意输入边界下，该文本严格等于已消费输入。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(let ((def (load-syntax-definition "scheme"))
      (doc "(define (square x)\n  (* x x))\n(display \"你好\")\n")
     ) ;
  (let ((s (make-structure-stream def (lambda (ev) #f))))
    (for-each (lambda (ch) (structure-stream-feed! s (string ch)))
      (string->list doc)
    ) ;for-each
    (structure-stream-finish! s)
    (check (structure-stream-text s) => doc)
  ) ;let
) ;let

;; 未闭合结构 EOF 交付后原文不丢失。
(let ((def (load-syntax-definition "scheme")))
  (let ((s (make-structure-stream def (lambda (ev) #f))))
    (structure-stream-feed! s "(a (b")
    (structure-stream-finish! s)
    (check (structure-stream-text s) => "(a (b")
  ) ;let
) ;let

(check-report)
