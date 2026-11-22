;; pi-effective-cfg-set!
;; 更新 runtime/effective-cfg 容器的当前值。
;;
;; 语法
;; ----
;; (pi-effective-cfg-set! box cfg)
;;
;; 参数
;; ----
;; box : vector?，pi-make-effective-cfg-box 创建的容器
;; cfg : any，要保存的配置
;;
;; 返回值
;; ----
;; unspecified

(import (scheme base) (liii check) (liii pi tui interactive worker-model))

(check-set-mode! 'report-failed)

;; 1. 覆盖旧配置
(let ((box (pi-make-effective-cfg-box 'before)))
  (pi-effective-cfg-set! box 'after)
  (check (pi-effective-cfg-ref box) => 'after)
) ;let

;; 2. 连续 set! 保留最后一次（latest-wins）
(let ((box (pi-make-effective-cfg-box 'first)))
  (pi-effective-cfg-set! box 'second)
  (pi-effective-cfg-set! box 'third)
  (check (pi-effective-cfg-ref box) => 'third)
) ;let

;; 3. 支持 #f 等任意值
(let ((box (pi-make-effective-cfg-box 'x)))
  (pi-effective-cfg-set! box #f)
  (check (pi-effective-cfg-ref box) => #f)
) ;let

(check-report)
