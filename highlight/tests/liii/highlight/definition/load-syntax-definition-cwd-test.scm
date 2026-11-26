;; load-syntax-definition
;; 验收用例：切换 cwd 后仍可通过 library-file 定位资源目录加载语法定义。
;;
;; 语法
;; ----
;; (load-syntax-definition name)
;;
;; 参数
;; ----
;; name : string
;; 语言标识。
;;
;; 返回值
;; ----
;; <definition>
;; 解析后的语法定义对象。

(import (scheme base)
  (scheme process-context)
  (liii check)
  (liii os)
  (liii path)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

;; 记录测试启动时的 cwd，便于最后还原

(define start-cwd (getcwd))

;; 切换到临时目录后再加载定义：definition.scm 在加载期已用 library-file
;; 缓存 resources/syntax 的绝对路径，运行期 cwd 变化不应影响资源定位。
(let ((tmp (or (get-environment-variable "TMPDIR") "/tmp")))
  (when (path-exists? tmp)
    (chdir tmp)
    (let ((def (load-syntax-definition "scheme")))
      (check (definition-name def) => "Scheme")
      (check (definition-initial-context-name def) => "Level0")
      ;; 切换 cwd 后仍能高亮
      (let-values (((spans st) (highlight-line "(define x 42)" (initial-highlight-state def) def))
                  ) ;
        (check-true (pair? spans))
        (check-true
          (any (lambda (sp) (string=? (caddr sp) "Extension")) spans)
        ) ;check-true
      ) ;let-values
    ) ;let
    ;; Markdown fenced scheme 在切 cwd 后仍生成嵌套高亮
    (let ((md (load-syntax-definition "markdown")))
      (let-values (((s1 st1) (highlight-line "```scheme" (initial-highlight-state md) md)))
        (let-values (((s2 st2) (highlight-line "(define x 42)" st1 md)))
          (check-true
            (any (lambda (sp) (string=? (caddr sp) "Extension")) s2)
          ) ;check-true
          (check-true
            (any (lambda (sp) (string=? (caddr sp) "DecVal")) s2)
          ) ;check-true
        ) ;let-values
      ) ;let-values
    ) ;let
  ) ;when
) ;let

;; 还原 cwd，避免影响后续测试
(when (path-exists? start-cwd)
  (chdir start-cwd)
) ;when

(check-report)
