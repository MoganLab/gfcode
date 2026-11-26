;; ensure-message-slots
;; 惰性补齐 turn-box 的消息缓冲槽、首行已打印标记槽与思考状态盒槽。
;;
;; 语法
;; ----
;; (ensure-message-slots turn-box)
;;
;; 参数
;; ----
;; turn-box : pair?
;; 包含轮次的可变列表，元素不足时惰性补齐。
;;
;; 返回值
;; ----
;; unspecified

(import (scheme base) (liii check) (liii pi code modes verbose state))

(check-set-mode! 'report-failed)

;; 1. 仅含轮次时补齐全部槽位
(let ((tb (list 0)))
  (ensure-message-slots tb)
  (check (car tb) => 0)
  (check (cadr tb) => "")
  (check (caddr tb) => #f)
  (check-true (vector? (cadddr tb)))
) ;let

;; 2. 已含消息缓冲时不再重复追加，仅补齐缺失槽位
(let ((tb (list 0 "buf")))
  (ensure-message-slots tb)
  (check (cadr tb) => "buf")
  (check (caddr tb) => #f)
  (check-true (vector? (cadddr tb)))
) ;let

;; 3. 已含思考盒时保留既有思考盒，不覆盖为默认值
(let ((tb (list 0 "" #f (vector #t 100 200))))
  (ensure-message-slots tb)
  (check (vector-ref (cadddr tb) 0) => #t)
  (check (vector-ref (cadddr tb) 1) => 100)
  (check (vector-ref (cadddr tb) 2) => 200)
) ;let

;; 4. 重复调用幂等，不破坏已补齐的结构
(let ((tb (list 0)))
  (ensure-message-slots tb)
  (ensure-message-slots tb)
  (check (length tb) => 4)
  (check (cadr tb) => "")
  (check (caddr tb) => #f)
) ;let

(check-report)
