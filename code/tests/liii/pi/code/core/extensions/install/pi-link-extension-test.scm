;; pi-link-extension
;; 把本地扩展目录链接到用户级或项目级扩展目录，供开发联调。
;;
;; 语法
;; ----
;; (pi-link-extension dir . opts)
;;
;; 参数
;; ----
;; dir : string
;; 本地扩展源码目录：包形式 gfcode/<name>/index.scm 或单文件 <name>.scm。
;;
;; opts : list?
;; 可选关键字参数：:local?（项目级链接）、:agent-dir、:cwd。
;;
;; 返回值
;; ------
;; string
;; 链接目标绝对路径（~/.gf/gfcode/<name> 或 {cwd}/.gf/gfcode/<name>）。
;; 目标已存在或源目录不含扩展时抛 value-error，建链接失败抛 install-error。

(import (scheme base)
  (liii check)
  (liii string)
  (liii path)
  (liii shutil)
  (liii os)
  (liii pi code core extensions install)
) ;import

(check-set-mode! 'report-failed)

;; 公用临时目录：agent-dir 与 cwd 都落在其下，避免触碰真实 ~/.gf 与当前工作目录。

(define (%make-sandbox)
  (let* ((temp
           (path-join (path-temp-dir)
             (string-append "gf-link-ext-" (number->string (getpid)))
           ) ;path-join
         ) ;temp
        ) ;
    (when (path-exists? temp)
      (rmtree (path->string temp) #t)
    ) ;when
    (path-mkdir temp :parents #t :exist-ok #t)
    temp
  ) ;let*
) ;define

;; 在沙箱内构造一个包形式扩展源目录，返回其绝对路径字符串。

(define (%make-pkg-source sandbox name)
  (let* ((src (path-join sandbox "sources" name)))
    (path-mkdir (path-join src "gfcode" name) :parents #t :exist-ok #t)
    (path-write-text (path-join src "gfcode" name "index.scm")
      (string-append ";; " name " entry\n")
    ) ;path-write-text
    (path->string src)
  ) ;let*
) ;define

;; 1. 用户级链接（默认）：目标落在 <agent-dir>/../gfcode/<name>
(let* ((sandbox (%make-sandbox))
       (agent-dir (path->string (path-join sandbox "agent")))
       (cwd-dir (path->string (path-join sandbox "project")))
       (src (%make-pkg-source sandbox "alpha"))
      ) ;
  (path-mkdir (path agent-dir) :parents #t :exist-ok #t)
  (path-mkdir (path cwd-dir) :parents #t :exist-ok #t)
  (let ((target (pi-link-extension src :local? #f :agent-dir agent-dir :cwd cwd-dir)))
    (check-true (string? target))
    (check-true (path-exists? (path target)))
    (check-true (path-exists? (path-join (path target) "index.scm")))
  ) ;let
  (rmtree (path->string sandbox) #t)
) ;let*

;; 2. 项目级链接（:local? #t）：目标落在 {cwd}/.gf/gfcode/<name>
(let* ((sandbox (%make-sandbox))
       (agent-dir (path->string (path-join sandbox "agent")))
       (cwd-dir (path->string (path-join sandbox "project")))
       (src (%make-pkg-source sandbox "beta"))
      ) ;
  (path-mkdir (path agent-dir) :parents #t :exist-ok #t)
  (path-mkdir (path cwd-dir) :parents #t :exist-ok #t)
  (let ((target (pi-link-extension src :local? #t :agent-dir agent-dir :cwd cwd-dir)))
    (check-true (string? target))
    (check-true (path-exists? (path target)))
    ;; 目标必须在 cwd 下的 .gf/gfcode/，不在 agent 侧
    (check-true (string-contains? target ".gf"))
    (check-true (path-exists? (path-join (path cwd-dir) ".gf" "gfcode" "beta")))
  ) ;let
  (rmtree (path->string sandbox) #t)
) ;let*

;; 3. 目标已存在时抛 value-error，不覆盖既有链接
(let* ((sandbox (%make-sandbox))
       (agent-dir (path->string (path-join sandbox "agent")))
       (cwd-dir (path->string (path-join sandbox "project")))
       (src (%make-pkg-source sandbox "gamma"))
      ) ;
  (path-mkdir (path agent-dir) :parents #t :exist-ok #t)
  (path-mkdir (path cwd-dir) :parents #t :exist-ok #t)
  (pi-link-extension src :local? #f :agent-dir agent-dir :cwd cwd-dir)
  (check-catch 'value-error
    (pi-link-extension src :local? #f :agent-dir agent-dir :cwd cwd-dir)
  ) ;check-catch
  (rmtree (path->string sandbox) #t)
) ;let*

;; 4. 源目录不含扩展时抛 value-error
(let* ((sandbox (%make-sandbox))
       (agent-dir (path->string (path-join sandbox "agent")))
       (cwd-dir (path->string (path-join sandbox "project")))
       (bad-src (path->string (path-join sandbox "noext")))
      ) ;
  (path-mkdir (path agent-dir) :parents #t :exist-ok #t)
  (path-mkdir (path cwd-dir) :parents #t :exist-ok #t)
  (path-mkdir (path bad-src) :parents #t :exist-ok #t)
  (path-write-text (path-join (path bad-src) "README.txt") "not an extension")
  (check-catch 'value-error
    (pi-link-extension bad-src :local? #t :agent-dir agent-dir :cwd cwd-dir)
  ) ;check-catch
  (rmtree (path->string sandbox) #t)
) ;let*

;; 5. 不存在的源目录抛 value-error
(let* ((sandbox (%make-sandbox))
       (agent-dir (path->string (path-join sandbox "agent")))
       (cwd-dir (path->string (path-join sandbox "project")))
      ) ;
  (path-mkdir (path agent-dir) :parents #t :exist-ok #t)
  (path-mkdir (path cwd-dir) :parents #t :exist-ok #t)
  (check-catch 'value-error
    (pi-link-extension (path->string (path-join sandbox "does-not-exist-xyz"))
      :local?    #t
      :agent-dir agent-dir
      :cwd       cwd-dir
    ) ;pi-link-extension
  ) ;check-catch
  (rmtree (path->string sandbox) #t)
) ;let*

(check-report)
