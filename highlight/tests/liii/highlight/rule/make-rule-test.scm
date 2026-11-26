;; make-rule
;; 构造一条高亮规则。
;;
;; 语法
;; ----
;; (make-rule type attribute context-target)
;; (make-rule type attribute context-target data look-ahead? first-non-space? column)
;;
;; 参数
;; ----
;; type : symbol
;; 规则类型，如 'detect-char、'keyword 等。
;;
;; attribute : string
;; 匹配成功后输出的 itemData 名称。
;;
;; context-target : list
;; 上下文切换指令，如 '(stay)、'(push "x")、'(pop 1)。
;;
;; data : object (可选)
;; 规则专有负载，默认 #f。
;;
;; look-ahead? : boolean (可选)
;; 是否前瞻（匹配但不前进），默认 #f。
;;
;; first-non-space? : boolean (可选)
;; 是否仅行首第一个非空白字符处可匹配，默认 #f。
;;
;; column : integer (可选)
;; 限定匹配列号，默认 -1 表示不限制。
;;
;; 返回值
;; ----
;; <rule>
;; 规则对象。

(import (scheme base) (liii check) (liii highlight rule))

(check-set-mode! 'report-failed)

;; 必填参数构造
(let ((r (make-rule 'detect-char "Normal" '(stay) #\()))
  (check-true (rule? r))
  (check (rule-type r) => 'detect-char)
  (check (rule-attribute r) => "Normal")
  (check (rule-context-target r) => '(stay))
  (check (rule-data r) => #\()
) ;let

;; 可选参数默认值
(let ((r (make-rule 'detect-spaces "Normal" '(stay))))
  (check (rule-data r) => #f)
  (check (rule-look-ahead? r) => #f)
  (check (rule-first-non-space? r) => #f)
  (check (rule-column r) => -1)
) ;let

;; 全参数构造
(let ((r (make-rule 'string-detect "Region" '(push "R") "BEGIN" #t #t 0)))
  (check (rule-data r) => "BEGIN")
  (check (rule-look-ahead? r) => #t)
  (check (rule-first-non-space? r) => #t)
  (check (rule-column r) => 0)
) ;let

(check-report)
