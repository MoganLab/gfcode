;; pi-footer-right-part
;; 组装页脚右下角模型串（含 all-in-one 实际节点的 "链 -> 节点" 展示）。
;;
;; 语法
;; ----
;; (pi-footer-right-part provider model thinking-level supports-thinking? active-node)
;;
;; 参数
;; ----
;; provider、model、thinking-level : (or string #f)
;; supports-thinking? : boolean
;; active-node : (or list #f)
;;
;; 返回值
;; ----
;; string

(import (scheme base) (liii check) (liii pi app interactive footer-model))

(check-set-mode! 'report)

(check (pi-footer-right-part "google" "gemini-4-hydrogen" "medium" #t #f)
  =>
  "(google) gemini-4-hydrogen • medium"
) ;check

(check (pi-footer-right-part "all-in-one"
         "coding-fast"
         "medium"
         #t
         '("minimax-cn" "MiniMax-M3.1-Flash" "medium" 262144 #t)
       ) ;pi-footer-right-part
  =>
  "all-in-one/coding-fast -> (minimax-cn) MiniMax-M3.1-Flash • medium"
) ;check

(check-report)
