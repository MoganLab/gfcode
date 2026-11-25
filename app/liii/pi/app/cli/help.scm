;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi app cli help)
  (import (scheme base)
    (scheme write)
    (liii raw-string)
    (liii json)
    (liii path)
    (liii string)
    (liii sys)
    (srfi srfi-13)
    (liii gfproject tools)
  ) ;import
  (export PI_HELP_TEXT display-pi-help)
  (begin
    ;; 库体顶层缓存本源码文件的绝对路径，用于判定正式安装 / 开发者模式。
    (define %self-source-file (library-file))

    ;; 正式安装布局：库位于 ~/.gf/site-lisp 之下；否则为开发者模式。
    (define (%dev-mode?)
      (and %self-source-file
        (catch #t
          (lambda ()
            (not (path-starts-with? (path %self-source-file)
                   (path-join (path-home) ".gf" "site-lisp")
                 ) ;path-starts-with?
            ) ;not
          ) ;lambda
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    ;; 把绝对路径中的 home 前缀缩写成 ~，分隔符统一为 /。
    (define (%abbreviate-home dir)
      (let* ((posix (path-as-posix (path dir)))
             (home
               (catch #t (lambda () (path-as-posix (path-home))) (lambda args #f))
             ) ;home
            ) ;
        (if (and home (string-prefix? home posix))
          (let ((rest (substring posix (string-length home))))
            (if
              (or (string-null? rest)
                (and (> (string-length rest) 0) (char=? (string-ref rest 0) #\/))
              ) ;or
              (string-append "~" rest)
              posix
            ) ;if
          ) ;let
          posix
        ) ;if
      ) ;let*
    ) ;define

    ;; 源码仓库根：.../<repo>/app/liii/pi/app/cli/help.scm 上溯 5 级。
    (define (%source-repo-root)
      (and %self-source-file
        (catch #t
          (lambda ()
            (let loop
              ((p (path-parent (path %self-source-file))) (n 0))
              (if (= n 5) (path->string p) (loop (path-parent p) (+ n 1)))
            ) ;let
          ) ;lambda
          (lambda args #f)
        ) ;catch
      ) ;and
    ) ;define

    ;; 开发者模式标记：" (~/git/gfcode2)"；正式安装为空串。
    (define (%dev-suffix)
      (if (%dev-mode?)
        (let ((root (%source-repo-root)))
          (if root (string-append " (" (%abbreviate-home root) ")") "")
        ) ;let
        ""
      ) ;if
    ) ;define

    ;; 读取 gfcode 自身 gfproject.json 的 package.version；失败回退 Goldfish 的 (version)。
    (define (%pi-version)
      (catch #t
        (lambda ()
          (let* ((bundle (gfproject-resolve-tool-bundle "pi"))
                 (base (bundle-ref bundle "tool_base_dir"))
                ) ;
            (if (not (string? base))
              (version)
              (let* ((file (path->string (path-join (path base) "gfproject.json")))
                     (pkg (json-ref (string->json (path-read-text file)) "package"))
                    ) ;
                (or (json-ref-string pkg "version" #f) (version))
              ) ;let*
            ) ;if
          ) ;let*
        ) ;lambda
        (lambda args (version))
      ) ;catch
    ) ;define

    (define (%pi-help-text)
      (string-append "gf pi v"
        (%pi-version)
        (%dev-suffix)
        "\n"
        (&- #""
          gf pi - AI coding assistant script mode

          Usage:
            gf pi [options] [--] [@files...] [messages...]
            gf pi auth print-api-key --provider <provider>

          Options:
            -p, --print                    Print response to stdout and exit
                --mode <mode>              Output mode: text, json, verbose (default: verbose)
                --model <id>               Model ID to use
                --provider <name>          Provider to search for --model (requires --model)
                --thinking <level>         Thinking level: off, minimal, low, medium, high, xhigh, max
                --list-models [search]     List all models with activation status (with optional search)
                --proxy <url>              Proxy URL (e.g. socks5h://127.0.0.1:1080)
                --tools <list>             Comma-separated list of tools
                --exclude-tools <list>     Comma-separated list of tools to exclude
                --no-tools                 Disable all tools
                --no-builtin-tools         Alias for --no-tools
                --max-turns <n>            Maximum turns limit (0 or unset for unlimited)
                --timeout <seconds>        Timeout in seconds for bash and HTTP (default: 600)
                --session-timeout <seconds>
                                           Total session timeout in seconds (default: 0, unlimited)
            -c, --continue                 Continue previous session
            -r, --resume                   Select a session to resume
            -n, --name <name>              Set session display name
                --compact                  Compact latest session, then run the prompt (if any)
                --no-auto-compact          Disable automatic context compaction
                --no-session               Do not persist session
                --session-dir <dir>        Directory for session storage and lookup
                                           (overrides PI_CODING_AGENT_SESSION_DIR
                                           and sessionDir in settings.json)
                --code-review              Review uncommitted changes and print a report
                --simplify                 Review uncommitted changes for simplification (read-only)
                --apply                    With --simplify, apply within-range changes
                --staged                   With --code-review/--simplify, review only staged changes
                --ref <ref>                With --code-review/--simplify, diff against the given ref
                --auto-review              Inject a per-language review checklist after write/edit
                --system-prompt <text>     Override system prompt
                --append-system-prompt <text>
                                           Append system prompt section
                --skill <path>             Add a skill directory or SKILL.md path (repeatable)
                --skills <path>            Alias for --skill
                --no-skills                Disable skill loading entirely
            -h, --help                     Show this help message

          Retry:
            Retriable provider errors (429/5xx/408/409/network) use the budget from
            retry.provider.maxRetries in the agent config directory
            (~/.gf/agent/settings.json),
            falling back to retry.maxRetries when the nested section is absent.
          ""
        ) ;&-
        "\n"
      ) ;string-append
    ) ;define

    ;; 完整帮助文本：首行含版本号与开发者模式标记。
    (define PI_HELP_TEXT (%pi-help-text))

    (define (display-pi-help)
      (display PI_HELP_TEXT)
    ) ;define
  ) ;begin
) ;define-library
