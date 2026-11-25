;; pi-make-effective-cfg-box
;; 创建 runtime/effective-cfg 容器：vector(1) 表示可变 box，
;; 贯穿同一 Worker 的多个 job，由 prepare-request 在每次请求前更新。
;;
;; 语法
;; ----
;; (pi-make-effective-cfg-box initial-cfg)
;;
;; 参数
;; ----
;; initial-cfg : any，初始有效配置
;;
;; 返回值
;; ----
;; vector?，长度为 1 的可变容器

(import (scheme base) (liii check) (liii pi app interactive worker-model))

(check-set-mode! 'report-failed)

;; 1. 返回长度为 1 的 vector，初始读取即初始配置
(let* ((initial (list (cons 'provider "google") (cons 'model-id "gemini-2.5-pro")))
       (box (pi-make-effective-cfg-box initial))
      ) ;
  (check-true (vector? box))
  (check (vector-length box) => 1)
  (check (pi-effective-cfg-ref box) => initial)
) ;let*

;; 2. 容器可变：set! 后读取得到新配置，旧值被替换
(let* ((initial (list (cons 'provider "google")))
       (box (pi-make-effective-cfg-box initial))
       (updated (list (cons 'provider "anthropic")))
      ) ;
  (pi-effective-cfg-set! box updated)
  (check (pi-effective-cfg-ref box) => updated)
  (check-false (equal? (pi-effective-cfg-ref box) initial))
) ;let*

;; 3. 多个容器互不影响
(let* ((a (pi-make-effective-cfg-box 'a)) (b (pi-make-effective-cfg-box 'b)))
  (pi-effective-cfg-set! a 'a2)
  (check (pi-effective-cfg-ref a) => 'a2)
  (check (pi-effective-cfg-ref b) => 'b)
) ;let*

(check-report)
