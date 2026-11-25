;; parse-pi-args
;; 用户级扩展覆盖内置同名扩展时，注册表只挂载胜出副本：
;; 默认注册表初始化经 pi-discover-extensions 仲裁一次性加载全部层级，
;; listeners / prompt-injectors / flags 等不得因「内置 + 用户」两批加载而重复。
;;
;; 语法
;; ----
;; (parse-pi-args argv)
;;
;; 参数
;; ----
;; argv : list
;; 不包含可执行文件名称的字符串参数列表。
;;
;; 返回值
;; ----
;; <pi-cli-args>
;; 解析结果记录；用户扩展注册的 flag 参与解析。

(import (scheme base)
  (scheme process-context)
  (liii check)
  (liii os)
  (liii path)
  (liii shutil)
  (liii pi code cli args)
  (liii pi code core extensions)
) ;import

(check-set-mode! 'report-failed)

;; 构造隔离环境：临时 HOME + 临时内置目录，
;; 内置与用户目录各放一个同名扩展 user-override-probe.scm，
;; 二者注册同名 flag / agent_end listener / prompt-injector，内容以标记区分。
;; 注意：环境必须在首次访问 default-extension-registry 之前布置好，
;; 扩展加载 initializer 每进程只执行一次。

(define (%probe-source mark)
  (string-append "(define-library (gfcode user-override-probe)\n"
    "  (import (scheme base) (liii pi code core extensions)) (export extension)\n"
    "  (begin (define (extension api . ctx)\n" "    (register-flag! api\n"
    "      (make-extension-flag-def \"--probe-mark\" \"probe\" :key 'probe-mark\n"
    "        :takes-arg? #t))\n"
    "    (pi-on! api 'agent_end (lambda (payload c) '" mark "))\n"
    "    (register-prompt-injector! api (lambda (tool-calls) #f))\n" "    '"
    mark ")))\n"
  ) ;string-append
) ;define

(let* ((root (path-join (path-temp-dir) "pi-user-override-probe"))
       (home (path-join root "home"))
       (builtin (path-join root "builtin" "gfcode"))
       (user-ext (path-join home ".gf" "gfcode"))
       (saved-home (get-environment-variable "HOME"))
       (saved-profile (get-environment-variable "USERPROFILE"))
       (saved-builtin (get-environment-variable "PI_BUILTIN_EXTENSIONS_DIR"))
       (saved-agent (get-environment-variable "PI_CODING_AGENT_DIR"))
       (saved-gf (get-environment-variable "GF_CONFIG_DIR"))
      ) ;
  (path-mkdir builtin :parents #t :exist-ok #t)
  (path-mkdir user-ext :parents #t :exist-ok #t)
  (path-write-text (path-join builtin "user-override-probe.scm")
    (%probe-source "builtin")
  ) ;path-write-text
  (path-write-text (path-join user-ext "user-override-probe.scm")
    (%probe-source "user")
  ) ;path-write-text
  (putenv "HOME" (path->string home))
  (when (os-windows?)
    (putenv "USERPROFILE" (path->string home))
  ) ;when
  (putenv "PI_BUILTIN_EXTENSIONS_DIR" (path->string builtin))
  (unsetenv "PI_CODING_AGENT_DIR")
  (unsetenv "GF_CONFIG_DIR")

  ;; 1. parse-pi-args 首次触发默认注册表初始化：用户副本的 flag 生效
  (let ((parsed (parse-pi-args '("--probe-mark" "x"))))
    (check (pi-args-ref parsed 'probe-mark) => "x")
  ) ;let

  ;; 2. agent_end listener 只挂 1 个，且为用户副本（返回 'user）
  (let* ((reg (default-extension-registry))
         (listeners (extension-registry-get-listeners reg 'agent_end))
        ) ;
    (check (length listeners) => 1)
    (check ((car listeners) '() #f) => 'user)
  ) ;let*

  ;; 3. prompt-injector 只挂 1 个（append 型注册不因两层加载而翻倍）
  (check (length (extension-registry-prompt-injectors (default-extension-registry)))
    =>
    1
  ) ;check

  ;; 恢复环境变量
  (if saved-home (putenv "HOME" saved-home) (unsetenv "HOME"))
  (when (os-windows?)
    (if saved-profile (putenv "USERPROFILE" saved-profile) (unsetenv "USERPROFILE"))
  ) ;when
  (if saved-builtin
    (putenv "PI_BUILTIN_EXTENSIONS_DIR" saved-builtin)
    (unsetenv "PI_BUILTIN_EXTENSIONS_DIR")
  ) ;if
  (if saved-agent
    (putenv "PI_CODING_AGENT_DIR" saved-agent)
    (unsetenv "PI_CODING_AGENT_DIR")
  ) ;if
  (if saved-gf (putenv "GF_CONFIG_DIR" saved-gf) (unsetenv "GF_CONFIG_DIR"))
  (rmtree (path->string root) #t)
) ;let*

(check-report)
