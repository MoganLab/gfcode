;; make-review-session-request
;; 构造会话执行请求结果。
;;
;; 语法
;; ----
;; (make-review-session-request parsed config prompt on-finish run-isolated notice records paths)
;;
;; 参数
;; ----
;; parsed config prompt on-finish run-isolated notice records paths — 各字段值
;;
;; 返回值
;; ----
;; review-session-request

(import (liii check) (liii pi code core extension-result))

(check-set-mode! 'report-failed)

(let ((r (make-review-session-request (list (cons 'a 1))
           (list (cons 'b 2))
           "p"
           (lambda _ #f)
           (lambda (thunk) (thunk))
           #f
           '()
           '("x")
         ) ;make-review-session-request
      ) ;r
     ) ;
  (check-true (review-session-request? r))
  (check (review-session-request-prompt r) => "p")
  (check (review-session-request-paths r) => '("x"))
) ;let

(check-report)
