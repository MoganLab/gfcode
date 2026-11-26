;; highlight-text
;; 端到端高亮验证：对本仓库及本机关联仓库的真实源码文件执行 highlight-text。
;; 这些用例依赖外部路径，均以 path-exists? 守卫，缺失时自动跳过，不产生失败。
;;
;; 语法
;; ----
;; (highlight-text text def)
;;
;; 参数
;; ----
;; text : string
;; 多行文本。
;;
;; def : definition?
;; 语法定义对象。
;;
;; 返回值
;; ----
;; list
;; '((spans . "line-text") ...)，每行一个元素。

(import (scheme base)
  (scheme process-context)
  (liii check)
  (liii list)
  (liii path)
  (liii highlight definition)
  (liii highlight highlighter)
) ;import

(check-set-mode! 'report-failed)

;; 端到端测试：本仓库 JSON 文件
(let ((jdef (load-syntax-definition "json")))
  (for-each
    (lambda (rel)
      (let ((p (if (path-exists? rel) rel (string-append "../" rel))))
        (when (path-exists? p)
          (let* ((text (path-read-text p)) (res (highlight-text text jdef)))
            (check-true (> (length res) 0))
          ) ;let*
        ) ;when
      ) ;let
    ) ;lambda
    '("gfproject.json" "gf_check.json" "highlight/resources/syntax/json.json"
      "highlight/resources/syntax/scheme.json")
  ) ;for-each
) ;let

;; 端到端测试：~/git/goldfish 仓库 JSON 文件
(let* ((jdef (load-syntax-definition "json"))
       (home (or (get-environment-variable "USERPROFILE")
               (get-environment-variable "HOME")
               ""
             ) ;or
       ) ;home
       (gf-dir (string-append home "/git/goldfish"))
      ) ;
  (when (path-exists? gf-dir)
    (for-each
      (lambda (rel)
        (let ((full (string-append gf-dir "/" rel)))
          (when (path-exists? full)
            (let* ((text (path-read-text full)) (res (highlight-text text jdef)))
              (check-true (> (length res) 0))
            ) ;let*
          ) ;when
        ) ;let
      ) ;lambda
      '("gfproject.json" "gf_check.json"
        "library/liii/json/schema/meta/draft2020-12/schema.json"
        "repl/package.json"
        "tools/pi/liii/pi/code/resources/all-in-one.schema.json")
    ) ;for-each
  ) ;when
) ;let*

;; 对齐上游测试：KDE syntax-highlighting autotests 的 test.json.witherror
(let* ((jdef (load-syntax-definition "json"))
       (home (or (get-environment-variable "USERPROFILE")
               (get-environment-variable "HOME")
               ""
             ) ;or
       ) ;home
       (input-p (string-append home
                  "/git/syntax-highlighting/autotests/input/test.json.witherror"
                ) ;string-append
       ) ;input-p
       (ref-p (string-append home
                "/git/syntax-highlighting/autotests/reference/test.json.witherror.ref"
              ) ;string-append
       ) ;ref-p
      ) ;
  (when (and (path-exists? input-p) (path-exists? ref-p))
    (let* ((input-text (path-read-text input-p)) (res (highlight-text input-text jdef)))
      ;; 22 行完整解析
      (check (= (length res) 22) => #t)
      ;; 第 4 行包含转义字符 Char 和错误 Error
      (let ((line4-spans (car (list-ref res 3))))
        (check-true
          (any (lambda (sp) (string=? (caddr sp) "Char")) line4-spans)
        ) ;check-true
        (check-true
          (any (lambda (sp) (string=? (caddr sp) "Error")) line4-spans)
        ) ;check-true
      ) ;let
    ) ;let*
  ) ;when
) ;let*

;; 端到端测试：~/git/mogan 仓库 C++ 代码
(let* ((cppdef (load-syntax-definition "cpp"))
       (home (or (get-environment-variable "USERPROFILE")
               (get-environment-variable "HOME")
               ""
             ) ;or
       ) ;home
       (mogan-dir (string-append home "/git/mogan"))
      ) ;
  (when (path-exists? mogan-dir)
    (for-each
      (lambda (rel)
        (let ((full (string-append mogan-dir "/" rel)))
          (when (path-exists? full)
            (let* ((text (path-read-text full)) (res (highlight-text text cppdef)))
              (check-true (> (length res) 0))
            ) ;let*
          ) ;when
        ) ;let
      ) ;lambda
      '("src/Data/Convert/convert.hpp" "src/Data/Convert/Generic/generic.cpp"
        "src/Data/Document/new_data.hpp" "src/Data/History/archiver.cpp"
        "3rdparty/argh/argh.h")
    ) ;for-each
  ) ;when
) ;let*

;; 端到端测试：~/git/mogan 仓库 C 代码
(let* ((cdef (load-syntax-definition "c"))
       (home (or (get-environment-variable "USERPROFILE")
               (get-environment-variable "HOME")
               ""
             ) ;or
       ) ;home
       (mogan-dir (string-append home "/git/mogan"))
      ) ;
  (when (path-exists? mogan-dir)
    (for-each
      (lambda (rel)
        (let ((full (string-append mogan-dir "/" rel)))
          (when (path-exists? full)
            (let* ((text (path-read-text full)) (res (highlight-text text cdef)))
              (check-true (> (length res) 0))
            ) ;let*
          ) ;when
        ) ;let
      ) ;lambda
      '("3rdparty/curl-8.21.0/lib/altsvc.c" "3rdparty/curl-8.21.0/lib/connect.c"
        "3rdparty/curl-8.21.0/lib/cookie.c"
        "3rdparty/curl-8.21.0/lib/cfilters.c")
    ) ;for-each
  ) ;when
) ;let*

;; 端到端测试：~/git/mogan 仓库 Lua 代码
(let* ((luadef (load-syntax-definition "lua"))
       (home (or (get-environment-variable "USERPROFILE")
               (get-environment-variable "HOME")
               ""
             ) ;or
       ) ;home
       (mogan-dir (string-append home "/git/mogan"))
      ) ;
  (when (path-exists? mogan-dir)
    (for-each
      (lambda (rel)
        (let ((full (string-append mogan-dir "/" rel)))
          (when (path-exists? full)
            (let* ((text (path-read-text full)) (res (highlight-text text luadef)))
              (check-true (> (length res) 0))
            ) ;let*
          ) ;when
        ) ;let
      ) ;lambda
      '("xmake.lua" "src/Scheme/Glue/build_glue.lua"
        "src/Scheme/Glue/glue_basic.lua" "xmake/packages/a/argh/xmake.lua"
        "xmake/targets/imgui.lua" "3rdparty/doctest.lua")
    ) ;for-each
  ) ;when
) ;let*

;; 端到端测试：~/git/goldfish 仓库 Markdown 文件高亮
(let* ((mddef (load-syntax-definition "markdown"))
       (home (or (get-environment-variable "USERPROFILE")
               (get-environment-variable "HOME")
               ""
             ) ;or
       ) ;home
       (gf-dir (string-append home "/git/goldfish"))
      ) ;
  (when (path-exists? gf-dir)
    (for-each
      (lambda (rel)
        (let ((full (string-append gf-dir "/" rel)))
          (when (path-exists? full)
            (let* ((text (path-read-text full)) (res (highlight-text text mddef)))
              (check-true (> (length res) 0))
            ) ;let*
          ) ;when
        ) ;let
      ) ;lambda
      '("README.md" "README_ZH.md" "AGENTS.md" "tools/pi/README.md"
        "library/tests/liii/cmark/README.md" "3rdparty/cpr/README.md"
        "tools/json/tests/liii/goldjson/README.md"
        "demo/tests/liii/tui/snake/README.md")
    ) ;for-each

    ;; 针对 tools/pi/README.md 校验 Scheme 代码块规则生效
    (let ((pi-readme (string-append gf-dir "/tools/pi/README.md")))
      (when (path-exists? pi-readme)
        (let* ((text (path-read-text pi-readme))
               (res (highlight-text text mddef))
               (found-keyword? #f)
              ) ;
          (for-each
            (lambda (pair)
              (let ((spans (car pair)) (line (cdr pair)))
                (when (string=? line "(import (liii pi code config))")
                  (when
                    (any (lambda (sp) (string=? (caddr sp) "Keyword")) spans)
                    (set! found-keyword? #t)
                  ) ;when
                ) ;when
              ) ;let
            ) ;lambda
            res
          ) ;for-each
          (check-true found-keyword?)
        ) ;let*
      ) ;when
    ) ;let

    ;; 针对 3rdparty/cpr/README.md 校验 C++ 代码块规则生效
    (let ((cpr-readme (string-append gf-dir "/3rdparty/cpr/README.md")))
      (when (path-exists? cpr-readme)
        (let* ((text (path-read-text cpr-readme))
               (res (highlight-text text mddef))
               (found-preproc? #f)
              ) ;
          (for-each
            (lambda (pair)
              (let ((spans (car pair)) (line (cdr pair)))
                (when (string=? line "#include <cpr/cpr.h>")
                  (when
                    (any (lambda (sp) (string=? (caddr sp) "Preprocessor")) spans)
                    (set! found-preproc? #t)
                  ) ;when
                ) ;when
              ) ;let
            ) ;lambda
            res
          ) ;for-each
          (check-true found-preproc?)
        ) ;let*
      ) ;when
    ) ;let
  ) ;when
) ;let*

;; The link label and destination remain separate even when rendered verbatim.
(let* ((def (load-syntax-definition "markdown"))
       (spans (caar (highlight-text "[x](y)" def)))
      ) ;
  (check (map caddr spans) => '("Link" "Link" "Link" "Link URL" "Link URL"))
) ;let*

(check-report)
