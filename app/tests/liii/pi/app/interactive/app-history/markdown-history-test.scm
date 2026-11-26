;; pi-app-rebuild-history! : app, session path -> success boolean.
;; pi 1.4.0 SessionManager fixture; only assistant text goes through the real
;; shared worker. Restoring and resizing never change the session on disk.
;; 语法
;; ----
;; (pi-app-rebuild-history! app file)
;; 参数
;; ----
;; app：应用；file：会话路径。
;; 返回值
;; ----
;; 重建成功返回 #t，不修改会话文件。
(import (scheme base)
  (scheme file)
  (liii path)
  (liii path stat)
  (liii list)
  (liii string)
  (liii check)
  (liii tui)
  (liii time)
  (liii go)
  (liii pi app interactive app)
  (liii pi app interactive state)
  (liii pi app interactive diff-worker)
  (liii pi app interactive app-history)
  (liii pi app interactive views assistant)
) ;import
(check-set-mode! 'report-failed)

(define file
  (if (file-exists? "tests/fixtures/pi-agent-markdown.jsonl")
    "tests/fixtures/pi-agent-markdown.jsonl"
    "app/tests/fixtures/pi-agent-markdown.jsonl"
  ) ;if
) ;define

(define original (path-read-text (path file)))

(define modified (path-stat-mtime (path-stat file)))

(define app
  (make-pi-app
    :terminal (make-virtual-terminal 80 24)
    :handler  (lambda args (error "unexpected model request"))
  ) ;make-pi-app
) ;define

(define jobs (%pi-app-display-jobs app))

(define events (pi-app-event-chan app))
(check-true (pi-app-rebuild-history! app file))

(define cards (filter assistant-card-component? (pi-app-chat app)))
(check (length (pi-app-chat app)) => 5)
(check (map assistant-card-text cards)
  =>
  '("# 标题\n```scheme\n(define x 1)\n```" "**第二块**")
) ;check

(define (render)
  (map (lambda (c) (component-render c 80)) cards)
) ;define

(define plain (render))
(go (%pi-display-worker jobs events))
(let loop
  ((remaining 200))
  (pi-app-poll-events! app)
  (when
    (and (> remaining 0)
      (any (lambda (pair) (apply equal? pair)) (map list plain (render)))
    ) ;and
    (sleep 0.01)
    (loop (- remaining 1))
  ) ;when
) ;let
(check-false (any (lambda (pair) (apply equal? pair)) (map list plain (render)))
) ;check-false
(check (map (lambda (ls) (map strip-ansi ls)) (render)) => plain)
;; Exercise the real display worker's syntax-resource lookup, not just the parser.

(define pr-link
  "**[#44 [1404] 修正版本更新范围并跳过纯版本提交发布](https://github.com/MoganLab/gfcode/pull/44)**"
) ;define
(chan-send! events (list 'assistant_text_delta pr-link) 100)
(pi-app-poll-events! app)

(define link-card (pi-app-assistant-card app))

(define (link-line)
  (car (component-render link-card 160))
) ;define
(let loop
  ((remaining 200))
  (pi-app-poll-events! app)
  (when
    (and (> remaining 0) (not (string-contains? (link-line) "\x1b;[4m")))
    (sleep 0.01)
    (loop (- remaining 1))
  ) ;when
) ;let
(check-true (string-contains? (link-line)
              "\x1b;[38;2;105;173;208m\x1b;[4m[#44 [1404] 修正版本更新范围并跳过纯版本提交发布]"
            ) ;string-contains?
) ;check-true
(check-true (string-contains? (link-line)
              "\x1b;[38;2;157;165;169mhttps://github.com/MoganLab/gfcode/pull/44"
            ) ;string-contains?
) ;check-true
(check (strip-ansi (link-line)) => pr-link)
(chan-close! jobs)
(check (path-read-text (path file)) => original)
(check (path-stat-mtime (path-stat file)) => modified)

(check-report)
