;; make-structure-definition
;; 构造并校验语义结构定义。
;;
;; 语法
;; ----
;; (make-structure-definition name role scope begin [end] [metadata] [children]
;;                            [include-begin?] [include-end?] [on-eof])
;;
;; 参数
;; ----
;; name : string
;; 语法定义内唯一的结构名称。
;;
;; role : symbol
;; 对调用方公开的结构角色，例如 heading、code-block 和 list。
;;
;; scope : symbol
;; line、delimited 或 nested。
;;
;; begin : string
;; 开始事件名称。
;;
;; end : string | #f (可选)
;; 结束事件名称；line 结构必须为 #f，其他结构必须提供非空字符串。
;;
;; metadata : alist (可选)
;; 静态元数据，例如 ((level . 1))。
;;
;; children : list (可选)
;; nested 结构允许的子结构名称列表。
;;
;; include-begin? : boolean (可选)
;; 片段是否包含开始标记，默认 #t。
;;
;; include-end? : boolean (可选)
;; 片段是否包含结束标记，默认 #t。
;;
;; on-eof : symbol (可选)
;; line 固定为 close；其他结构支持 emit-unclosed 和 error-and-emit。
;;
;; 返回值
;; -----
;; <structure-definition>
;; 已校验的结构定义。
;;
;; 错误处理
;; --------
;; structure-definition-error 当字段或 scope 组合不符合 Schema。
;;
;; line 只在真实换行或 EOF 闭合，输入块末尾不是边界。
;; delimited 使用独立开始/结束事件，适合 fenced code。
;; nested 可递归嵌套，适合 Scheme list 和 JSON object/array。

(import (scheme base) (liii check) (liii highlight structure))
(check-set-mode! 'report-failed)

;; Markdown # 标题：单行，不包含后续正文。
(let ((heading (make-structure-definition "heading-1"
                 'heading
                 'line
                 "heading-1-open"
                 #f
                 '((level . 1))
                 '()
                 #t
                 #t
                 'close
               ) ;make-structure-definition
      ) ;heading
     ) ;
  (check-true (structure-definition? heading))
  (check (structure-definition-name heading) => "heading-1")
  (check (structure-definition-role heading) => 'heading)
  (check (structure-definition-scope heading) => 'line)
  (check (structure-definition-begin heading) => "heading-1-open")
  (check (structure-definition-end heading) => #f)
  (check (structure-definition-metadata heading) => '((level . 1)))
  (check (structure-definition-on-eof heading) => 'close)
) ;let

;; Markdown fenced code：有独立开始和结束事件，EOF 可以未闭合交付。
(let ((code (make-structure-definition "fenced-code"
              'code-block
              'delimited
              "fence-open"
              "fence-close"
              '((language . "dynamic"))
              '()
              #t
              #t
              'emit-unclosed
            ) ;make-structure-definition
      ) ;code
     ) ;
  (check (structure-definition-scope code) => 'delimited)
  (check (structure-definition-end code) => "fence-close")
  (check (structure-definition-metadata code) => '((language . "dynamic")))
  (check (structure-definition-include-begin? code) => #t)
  (check (structure-definition-include-end? code) => #t)
  (check (structure-definition-on-eof code) => 'emit-unclosed)
) ;let

;; Scheme list 和 JSON object：允许递归嵌套。
(let ((list-def (make-structure-definition "list"
                  'list
                  'nested
                  "list-open"
                  "list-close"
                  '()
                  '("list" "string" "comment" "atom")
                ) ;make-structure-definition
      ) ;list-def
     ) ;
  (check (structure-definition-scope list-def) => 'nested)
  (check (structure-definition-children list-def)
    =>
    '("list" "string" "comment" "atom")
  ) ;check
  (check (structure-definition-on-eof list-def) => 'emit-unclosed)
) ;let

(let ((object (make-structure-definition "object"
                'object
                'nested
                "object-open"
                "object-close"
                '()
                '("object" "array" "member" "scalar")
                #t
                #t
                'error-and-emit
              ) ;make-structure-definition
      ) ;object
     ) ;
  (check (structure-definition-on-eof object) => 'error-and-emit)
) ;let

;; 非法 scope 组合和字段。
(check-catch 'structure-definition-error
  (make-structure-definition "bad" 'heading 'unknown "open")
) ;check-catch
(check-catch 'structure-definition-error
  (make-structure-definition "bad" 'heading 'line "open" "close")
) ;check-catch
(check-catch 'structure-definition-error
  (make-structure-definition "bad" 'list 'nested "open")
) ;check-catch
(check-catch 'structure-definition-error
  (make-structure-definition "bad"
    'list
    'nested
    "open"
    "close"
    '()
    '("list")
    #t
    #t
    'close
  ) ;make-structure-definition
) ;check-catch
(check-catch 'structure-definition-error
  (make-structure-definition "bad" 'list 'delimited "open" "close" '() '("list"))
) ;check-catch
(check-catch 'structure-definition-error
  (make-structure-definition "" 'list 'nested "open" "close")
) ;check-catch


(check-report)
