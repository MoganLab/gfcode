;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 斜杠命令菜单：识别输入行首的命令上下文，过滤命令并构建选择列表
(define-library (liii pi app interactive slash-command-menu)
  (export pi-slash-command-matches make-pi-slash-command-menu)
  (import (scheme base)
    (rename (only (liii pi app interactive views theme) %fg-accent %fg-output)
      (%fg-accent %accent)
      (%fg-output %muted)
    ) ;rename
    (liii string)
    (liii tui)
    (liii pi code core skills types)
    (liii pi code core extensions)
  ) ;import
  (begin

    (define %reset "\x1b;[0m")

    (define %commands
      (list (list (cons 'name "model") (cons 'description "Select model"))
        (list (cons 'name "thinking") (cons 'description "Set thinking level"))
        (list (cons 'name "name") (cons 'description "Get or set session name"))
        (list (cons 'name "session") (cons 'description "Show session statistics"))
        (list (cons 'name "resume") (cons 'description "Select and resume a session"))
        (list (cons 'name "config") (cons 'description "Edit providers and models"))
        (list (cons 'name "login")
          (cons 'description "Configure provider authentication")
        ) ;list
        (list (cons 'name "exit") (cons 'description "Exit gf"))
      ) ;list
    ) ;define

    (define (%colored color text)
      (string-append color text %reset)
    ) ;define

    (define (%skill->command s)
      (list (cons 'name (string-append "skill:" (pi-skill-name s)))
        (cons 'description (pi-skill-description s))
      ) ;list
    ) ;define

    ;; 扩展命令可能以带或不带前导斜杠的别名注册（如 "/review" 与 "review"），
    ;; 菜单按去斜杠后的规范名去重，内置命令优先；取首个见到的别名条目，
    ;; 避免同一命令在菜单中重复出现。注册表未加载或为空时返回空列表。
    (define (%strip-leading-slash name)
      (if (string-starts? name "/") (substring name 1 (string-length name)) name)
    ) ;define

    (define (%extension-commands)
      (let ((reg (catch #t (lambda () (default-extension-registry)) (lambda args #f))))
        (if (not reg)
          '()
          (let loop
            ((rest (extension-registry-commands-list reg)) (seen '()) (out '()))
            (if (null? rest)
              (reverse out)
              (let* ((cmd (car rest))
                     (raw (extension-command-def-name cmd))
                     (name (%strip-leading-slash raw))
                    ) ;
                (if (member name seen)
                  (loop (cdr rest) seen out)
                  (loop (cdr rest)
                    (cons name seen)
                    (cons (list (cons 'name name)
                            (cons 'description (extension-command-def-description cmd))
                          ) ;list
                      out
                    ) ;cons
                  ) ;loop
                ) ;if
              ) ;let*
            ) ;if
          ) ;let
        ) ;if
      ) ;let
    ) ;define

    ;; 仅在输入行（允许前导空白）以 / 开头且尚未输入命令参数时补全；
    ;; 当 enable-skill-commands? 为 #t 时，混入已发现的 /skill:<name> 命令；
    ;; 扩展命令（来自默认注册表）始终参与匹配，按去斜杠规范名去重，内置优先；
    ;; 无匹配时返回 #f，因此 /tmp 等路径不会留下空菜单。
    (define* (pi-slash-command-matches text (skills '()) (enable-skill-commands? #t))
      (let ((command-text (string-trim-left text)))
        (if (and (string-starts? command-text "/")
              (not (string-contains? command-text " "))
            ) ;and
          (let ((matches
                  (fuzzy-filter (append %commands
                                  (%extension-commands)
                                  (if enable-skill-commands? (map %skill->command skills) '())
                                ) ;append
                    (substring command-text 1 (string-length command-text))
                    (lambda (command) (cdr (assoc 'name command)))
                  ) ;fuzzy-filter
                ) ;matches
               ) ;
            (if (null? matches) #f matches)
          ) ;let
          #f
        ) ;if
      ) ;let
    ) ;define*

    (define (make-pi-slash-command-menu commands)
      (make-select-list
        (map
          (lambda (command)
            (let ((name (cdr (assoc 'name command))))
              (list (cons 'value name)
                (cons 'label (string-append "/" name))
                (cons 'description (cdr (assoc 'description command)))
              ) ;list
            ) ;let
          ) ;lambda
          commands
        ) ;map
        5
        :min-primary-column-width 12
        :max-primary-column-width 32
        :selected-text            (lambda (text) (%colored %accent text))
        :description-text         (lambda (text) (%colored %muted text))
        :scroll-text              (lambda (text) (%colored %muted text))
        :no-match-text            (lambda (text) (%colored %muted text))
      ) ;make-select-list
    ) ;define

  ) ;begin
) ;define-library
