;; pi-effective-cfg-ref
;; 读取 runtime/effective-cfg 容器的当前值。
;;
;; 语法
;; ----
;; (pi-effective-cfg-ref box)
;;
;; 参数
;; ----
;; box : vector?，pi-make-effective-cfg-box 创建的容器
;;
;; 返回值
;; ----
;; any，容器当前保存的配置

(import (scheme base) (liii check) (liii pi tui interactive worker-model))

(check-set-mode! 'report-failed)

;; 1. 读取初始配置
(let ((box (pi-make-effective-cfg-box 'initial)))
  (check (pi-effective-cfg-ref box) => 'initial)
) ;let

;; 2. set! 之后读取返回新值
(let ((box (pi-make-effective-cfg-box 'old)))
  (pi-effective-cfg-set! box 'new)
  (check (pi-effective-cfg-ref box) => 'new)
) ;let

;; 3. 重复读取结果一致（纯读取无副作用）
(let* ((box (pi-make-effective-cfg-box 'cfg))
       (r1 (pi-effective-cfg-ref box))
       (r2 (pi-effective-cfg-ref box))
      ) ;
  (check r1 => r2)
  (check r1 => 'cfg)
) ;let*

(check-report)
