;; make-structure-set
;; 构造语法定义的语义结构集合。
;;
;; 语法
;; ----
;; (make-structure-set [version] [default] [root-scope] [structures])
;;
;; 参数
;; ----
;; version : integer (可选)
;; Schema 版本，当前只支持 1。
;;
;; default : symbol (可选)
;; 未命中声明结构时的默认角色，当前只支持 text。
;;
;; root-scope : symbol (可选)
;; 根消费视图名称，例如 top-level 或 value。
;;
;; structures : list (可选)
;; <structure-definition> 列表，名称不得重复。
;;
;; 返回值
;; -----
;; <structure-set>
;; 已校验的结构集合。
;;
;; 错误处理
;; --------
;; structure-definition-error 当版本、默认角色或结构列表无效。
;;
;; 未声明结构的语法使用空 structure-set，现有高亮行为不变。

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)

(let ((empty (make-structure-set)))
  (check-true (structure-set? empty))
  (check (structure-set-version empty) => 1)
  (check (structure-set-default empty) => 'text)
  (check (structure-set-root-scope empty) => 'top-level)
  (check (structure-set-structures empty) => '())
) ;let

(let* ((heading (make-structure-definition "heading" 'heading 'line "heading-open"))
       (code (make-structure-definition "code"
               'code-block
               'delimited
               "fence-open"
               "fence-close"
             ) ;make-structure-definition
       ) ;code
       (set (make-structure-set 1 'text 'top-level (list heading code)))
      ) ;
  (check (= (length (structure-set-structures set)) 2) => #t)
  (check (structure-set-root-scope set) => 'top-level)
) ;let*

(let ((json-set (make-structure-set
                  :root-scope 'value
                  :structures
                  (list (make-structure-definition "object"
                          'object
                          'nested
                          "object-open"
                          "object-close"
                        ) ;make-structure-definition
                  ) ;list
                ) ;make-structure-set
      ) ;json-set
     ) ;
  (check (structure-set-root-scope json-set) => 'value)
) ;let

(check-catch 'structure-definition-error (make-structure-set 2))
(check-catch 'structure-definition-error (make-structure-set 1 'paragraph))
(check-catch 'structure-definition-error
  (make-structure-set 1 'text 'top-level '(bad))
) ;check-catch
(check-catch 'structure-definition-error
  (make-structure-set 1
    'text
    'top-level
    (list (make-structure-definition "duplicate" 'heading 'line "a")
      (make-structure-definition "duplicate" 'heading 'line "b")
    ) ;list
  ) ;make-structure-set
) ;check-catch


(check-report)
