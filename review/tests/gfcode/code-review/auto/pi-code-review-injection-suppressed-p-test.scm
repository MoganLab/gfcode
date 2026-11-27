;; pi-code-review-injection-suppressed?
;; 自动注入抑制标志变量：记录独立审查是否处于抑制窗口。
;;
;; 语法
;; ----
;; pi-code-review-injection-suppressed?
;;
;; 参数
;; ----
;; 无参数（变量）。
;;
;; 返回值
;; ----
;; boolean
;; 初始为 #f。该导出变量按值绑定，运行期的 suppress!/restore! 不会更新
;; import 侧的绑定；injector 应改用 pi-code-review-injection-enabled? 读取。

(import (liii check) (gfcode code-review auto))

(check-set-mode! 'report-failed)

(check (boolean? pi-code-review-injection-suppressed?) => #t)
(check pi-code-review-injection-suppressed? => #f)

(check-report)
