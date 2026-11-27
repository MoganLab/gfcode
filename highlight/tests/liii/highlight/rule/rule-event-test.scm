;; rule-event
;; 获取规则声明的结构事件名称。
;;
;; 语法
;; ----
;; (rule-event rule)
;;
;; 参数
;; ----
;; rule : rule?
;; 高亮规则对象。
;;
;; 返回值
;; -----
;; string | #f
;; 事件名称；未声明事件时为 #f。事件不影响匹配与高亮行为。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

;; 默认无事件
(let ((r (make-rule 'detect-char "Normal" '(stay) #\()))
  (check (rule-event r) => #f)
) ;let

;; 第 8 个可选参数声明事件
(let ((r (make-rule 'detect-char "Normal" '(push "Level1") #\( #f #f -1 "list-open"))
     ) ;
  (check (rule-event r) => "list-open")
  (check (rule-type r) => 'detect-char)
  (check (rule-context-target r) => '(push "Level1"))
) ;let

;; 关键字参数声明事件
(let ((r (make-rule 'string-detect
           "Header H1"
           '(push "header-1")
           "# "
           :event "heading-1-open"
         ) ;make-rule
      ) ;r
     ) ;
  (check (rule-event r) => "heading-1-open")
) ;let

(check-report)
