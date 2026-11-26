;; render-spans-to-ansi
;; 将单行 spans 渲染为带 ANSI 颜色的字符串。
;;
;; 语法
;; ----
;; (render-spans-to-ansi line spans th def)
;;
;; 参数
;; ----
;; line : string
;; 原始行文本。
;;
;; spans : list
;; '((offset length item-data-name) ...)。
;;
;; th : theme?
;; 主题对象。
;;
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; string
;; 带 ANSI 转义序列的渲染结果。

(import (scheme base)
  (liii check)
  (liii string)
  (liii highlight theme)
  (liii highlight definition)
  (liii highlight tui-render)
) ;import

(check-set-mode! 'report-failed)

(let ((th (default-breeze-dark-theme)) (def (load-syntax-definition "scheme")))
  ;; 空 spans：返回空串
  (check (render-spans-to-ansi "hello" '() th def) => "")

  ;; 单个 span：包上转义前缀和重置码
  (let ((out (render-spans-to-ansi "define" '((0 6 "Extension")) th def)))
    (check-true (string-starts? out "\x1b;["))
    (check-true (string-contains? out "define"))
    (check-true (string-ends? out "\x1b;[0m"))
  ) ;let

  ;; 多个 span：文本包含各段字符
  (let ((out (render-spans-to-ansi "(+ 1 2)"
               '((0 1 "Normal")
                 (1 1 "Operator")
                 (2 1 "Normal")
                 (3 1 "DecVal")
                 (4 1 "Normal")
                 (5 1 "DecVal")
                 (6 1 "Normal"))
               th
               def
             ) ;render-spans-to-ansi
        ) ;out
       ) ;
    (check-true (string-contains? out "+"))
    (check-true (string-contains? out "1"))
    (check-true (string-contains? out "2"))
  ) ;let

  ;; 未知 itemData 名：样式回退，文本仍输出
  (let ((out (render-spans-to-ansi "xyz" '((0 3 "NoSuchStyle")) th def)))
    (check-true (string-contains? out "xyz"))
  ) ;let
) ;let

(check-report)
