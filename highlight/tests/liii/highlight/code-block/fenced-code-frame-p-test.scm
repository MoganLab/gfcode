;; fenced-code-frame?
;; 判断栈帧是否为 Markdown 围栏代码块帧。
;;
;; 语法
;; ----
;; (fenced-code-frame? frame)
;;
;; 参数
;; ----
;; frame : any
;; 栈顶帧对象，围栏代码块帧形如 '(fenced-code fence-char fence-len lang-name sub-state)。
;;
;; 返回值
;; ----
;; boolean
;; 为围栏代码块帧返回 #t，否则 #f。

(import (scheme base) (liii check) (liii highlight code-block))

(check-set-mode! 'report-failed)

;; 围栏代码块帧：car 为 'fenced-code
(check-true (fenced-code-frame? (list 'fenced-code #\` 3 "scheme" #f)))
(check-true (fenced-code-frame? (list 'fenced-code #\~ 4 #f #f)))

;; 非围栏代码块帧
(check-false (fenced-code-frame? (list 'include #f '("Level0") "host" #f)))
(check-false (fenced-code-frame? '("string" "Level0")))
(check-false (fenced-code-frame? "string"))
(check-false (fenced-code-frame? '()))
(check-false (fenced-code-frame? #f))

(check-report)
