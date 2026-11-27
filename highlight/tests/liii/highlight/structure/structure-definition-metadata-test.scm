;; structure-definition-metadata
;; 获取静态结构元数据。
;;
;; 语法
;; ----
;; (structure-definition-metadata definition)
;;
;; 参数
;; ----
;; definition : structure-definition?
;;
;; 返回值
;; -----
;; alist

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)
(let ((heading (make-structure-definition "h" 'heading 'line "open" #f '((level
                                                                           . 1)))
      ) ;heading
     ) ;
  (check (structure-definition-metadata heading) => '((level . 1)))
) ;let

(check-report)
