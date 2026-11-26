;; highlight-text-to-ansi
;; 整段文本高亮渲染为 ANSI 字符串。
;;
;; 语法
;; ----
;; (highlight-text-to-ansi text def th)
;;
;; 参数
;; ----
;; text : string
;; 多行文本。
;;
;; def : definition?
;; 语法定义对象。
;;
;; th : theme?
;; 主题对象。
;;
;; 返回值
;; ----
;; string
;; 各行以 \n 连接的 ANSI 渲染结果。

(import (scheme base)
  (liii check)
  (liii string)
  (liii highlight theme)
  (liii highlight definition)
  (liii highlight tui-render)
) ;import

(check-set-mode! 'report-failed)

(let ((th (default-breeze-dark-theme)) (def (load-syntax-definition "scheme")))
  ;; 多行代码：保留换行与标识符
  (let ((ans (highlight-text-to-ansi "(define (add a b)\n  (+ a b))\n" def th)))
    (check-true (string-contains? ans "\n"))
    (check-true (string-contains? ans "add"))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let

  ;; 纯文本无样式场景：仍输出各词
  (let ((ans (highlight-text-to-ansi "plain text\n" def th)))
    (check-true (string-contains? ans "plain"))
    (check-true (string-contains? ans "text"))
  ) ;let

  ;; 空文本
  (let ((ans (highlight-text-to-ansi "" def th)))
    (check (string-length ans) => 0)
  ) ;let
) ;let

;; JSON ANSI 渲染
(let ((th (default-breeze-dark-theme)) (jdef (load-syntax-definition "json")))
  (let ((ans (highlight-text-to-ansi "{\"key\": [1, 2.5, true, null]}\n" jdef th)))
    (check-true (string-contains? ans "\x1b;["))
    (check-true (string-contains? ans "key"))
    (check-true (string-contains? ans "2.5"))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let
) ;let

;; C++ ANSI 渲染
(let ((th (default-breeze-dark-theme)) (cppdef (load-syntax-definition "cpp")))
  (let ((ans (highlight-text-to-ansi "#include <vector>\nint main() { return 0; }\n"
               cppdef
               th
             ) ;highlight-text-to-ansi
        ) ;ans
       ) ;
    (check-true (string-contains? ans "\x1b;["))
    (check-true (string-contains? ans "include"))
    (check-true (string-contains? ans "vector"))
    (check-true (string-contains? ans "main"))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let
) ;let

;; C ANSI 渲染
(let ((th (default-breeze-dark-theme)) (cdef (load-syntax-definition "c")))
  (let ((ans (highlight-text-to-ansi "/* hello */\n#include \"curl.h\"\nint main(void) { return 0; }\n"
               cdef
               th
             ) ;highlight-text-to-ansi
        ) ;ans
       ) ;
    (check-true (string-contains? ans "\x1b;["))
    (check-true (string-contains? ans "include"))
    (check-true (string-contains? ans "curl.h"))
    (check-true (string-contains? ans "main"))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let
) ;let

;; Lua ANSI 渲染
(let ((th (default-breeze-dark-theme)) (luadef (load-syntax-definition "lua")))
  (let ((ans (highlight-text-to-ansi "-- greeting\nlocal function hello()\n  print(\"hello lua\")\nend\n"
               luadef
               th
             ) ;highlight-text-to-ansi
        ) ;ans
       ) ;
    (check-true (string-contains? ans "\x1b;["))
    (check-true (string-contains? ans "greeting"))
    (check-true (string-contains? ans "local"))
    (check-true (string-contains? ans "function"))
    (check-true (string-contains? ans "hello lua"))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let
) ;let

;; Bash ANSI 渲染
(let ((th (default-breeze-dark-theme)) (bashdef (load-syntax-definition "bash")))
  (let ((ans (highlight-text-to-ansi "#!/usr/bin/env bash\nif [ -f \"$HOME/.bashrc\" ]; then\n  echo \"hi\"\nfi\n"
               bashdef
               th
             ) ;highlight-text-to-ansi
        ) ;ans
       ) ;
    (check-true (string-contains? ans "\x1b;["))
    (check-true (string-contains? ans "bashrc"))
    (check-true (string-contains? ans "echo"))
    (check-true (string-contains? ans "\x1b;[0m"))
  ) ;let
) ;let

(check-report)
