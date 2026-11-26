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
(chan-close! jobs)
(check (path-read-text (path file)) => original)
(check (path-stat-mtime (path-stat file)) => modified)

(check-report)
