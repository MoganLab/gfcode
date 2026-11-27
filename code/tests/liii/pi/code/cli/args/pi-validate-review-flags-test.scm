;; pi-validate-review-flags
;; 校验 review 相关命令行参数的组合合法性。
;;
;; 语法
;; ----
;; (pi-validate-review-flags parsed)
;;
;; 参数
;; ----
;; parsed : alist
;; 解析后的参数字典。
;;
;; 返回值
;; ----
;; 不返回
;; 参数组合非法时抛出错误。

(set! *load-path*
  (append (list "../review" "../web-search" "review" "web-search") *load-path*)
) ;set!

(import (liii check) (liii pi code cli args))

(check-set-mode! 'report-failed)

;; code-review 组合
(check (pi-validate-review-flags (parse-pi-args '("--code-review"))) => #t)
(check (pi-validate-review-flags (parse-pi-args '())) => #t)
(check (pi-validate-review-flags (parse-pi-args '("--code-review" "--staged")))
  =>
  #t
) ;check
(check (pi-validate-review-flags (parse-pi-args '("--code-review" "--ref=main")))
  =>
  #t
) ;check

;; 依赖缺失报可读错误；自动审查默认启用，--auto-review 已移除（进入 unknown-flags）
(check-catch 'pi-arg-error
  (pi-validate-review-flags (parse-pi-args '("--staged")))
) ;check-catch
(check-catch 'pi-arg-error
  (pi-validate-review-flags (parse-pi-args '("--ref=main")))
) ;check-catch

(check-report)
