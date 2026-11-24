;; make-pi-header
;; 构造并返回新的 make-pi-header 实例组件。
;;
;; 语法
;; ----
;; (make-pi-header ...)
;;
;; 参数
;; ----
;; 详见语法说明。
;;
;; 返回值
;; ----
;; component?
;; 返回构造的实例。

(import (scheme base)
  (liii check)
  (liii string)
  (liii tui text-width)
  (liii tui component)
  (liii pi tui interactive header)
) ;import

(check-set-mode! 'report)

(let* ((hdr (make-pi-header))
       (lines (component-render hdr 80))
       (plain-lines (map strip-ansi lines))
      ) ;
  (check (component? hdr) => #t)
  (check (length lines) => 6)
  (check (list-ref plain-lines 0) => "")
  (check-true (string-contains? (list-ref plain-lines 1) " gfcode v"))
  (check-true (string-contains? (list-ref plain-lines 1) (version)))
  ;; 本测试从源码仓库加载 header.scm，属开发者模式，版本号后应有仓库根标记 ( ... )。
  ;; 不断言具体仓库名（CI 上 checkout 目录名与本地可能不同）。
  (check-true (string-contains? (list-ref plain-lines 1) " ("))
  (check-true (string-contains? (list-ref plain-lines 1) ")"))
  (check-true (string-contains? (list-ref plain-lines 2) "escape interrupt"))
  (check-true (string-contains? (list-ref plain-lines 2) "ctrl+c/ctrl+d clear/exit")
  ) ;check-true
  (check-true (string-contains? (list-ref plain-lines 2) "ctrl+z undo"))
  (check-true (string-contains? (list-ref plain-lines 2) "/ commands"))
  (check-true (string-contains? (list-ref plain-lines 2) "! bash"))
  (check-false (string-contains? (list-ref plain-lines 2) "ctrl+o"))
  (check (list-ref plain-lines 3) => "")
  (check-true (string-contains? (list-ref plain-lines 4)
                "Goldfish Scheme Agent can explain its own features"
              ) ;string-contains?
  ) ;check-true
  (check (list-ref plain-lines 5) => "")
) ;let*

(let* ((hdr (make-pi-header :version "1.2.3"))
       (lines (component-render hdr 80))
       (plain-lines (map strip-ansi lines))
      ) ;
  (check-true (string-contains? (list-ref plain-lines 1) " gfcode v1.2.3"))
) ;let*

(check-report)
