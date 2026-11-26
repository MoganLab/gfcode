;; pi-app-rebuild-history!
;; 成功恢复历史后，隔离恢复前的 diff 和汇总事件。
;;
;; 语法
;; ----
;; (pi-app-rebuild-history! app session-file)
;;
;; 参数
;; ----
;; app : pi-app?，交互式应用实例；session-file : string?，会话 JSONL 路径。
;;
;; 返回值
;; ----
;; boolean?。成功替换聊天记录返回 #t，失败返回 #f；不改写会话文件。
(import (scheme base)
  (scheme file)
  (liii check)
  (liii go)
  (liii path)
  (liii string)
  (liii tempfile)
  (liii tui)
  (liii pi code core session-manager)
  (liii pi app interactive app)
  (liii pi app interactive app-history)
  (liii pi app interactive state)
) ;import

(check-set-mode! 'report-failed)

(let* ((tmp (make-temp-dir "gf-pi-diff-history-"))
       (file (path->string (path-join tmp "history.jsonl")))
       (date "2026-11-04T08:00:00.000Z")
       (app (make-pi-app
              :terminal     (make-virtual-terminal 100 30)
              :handler      (lambda args #f)
              :bash-handler (lambda args (values "" 0))
            ) ;make-pi-app
       ) ;app
       (events (pi-app-event-chan app))
      ) ;
  (define (emit . items)
    (for-each (lambda (event) (chan-send! events event 100)) items)
    (pi-app-poll-events! app)
  ) ;define
  (define (chat)
    (string-join (map strip-ansi (pi-app-transcript-lines app)) "\n")
  ) ;define
  (dynamic-wind (lambda () #t)
    (lambda ()
      (save-session-header! file "diff-resume" date tmp)
      (save-session-message! file
        (string-append "{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"History reply\"},"
          "{\"type\":\"toolCall\",\"id\":\"same\",\"name\":\"edit\",\"arguments\":{\"path\":\"never-read.txt\","
          "\"edits\":[{\"oldText\":\"old\",\"newText\":\"new\"}]}}]}"
        ) ;string-append
        "m1"
        #f
        date
      ) ;save-session-message!
      (save-session-message! file
        (string-append "{\"role\":\"toolResult\",\"toolCallId\":\"same\",\"toolName\":\"edit\","
          "\"content\":[{\"type\":\"text\",\"text\":\"Historical tool result\"}],\"isError\":false}"
        ) ;string-append
        "m2"
        "m1"
        date
      ) ;save-session-message!
      (let ((original (path-read-text file)))
        (emit '(run_started 1)
          '(diff_result 1 "same" "never-read.txt" "+old-live" 1 1 1)
          '(turn_diff_summary 1 (("never-read.txt" 1 1)))
        ) ;emit
        (check-true (pi-app-rebuild-history! app file))
        (emit '(diff_result 1 "same" "never-read.txt" "+late-live" 1 1 1)
          '(turn_diff_summary 1 (("never-read.txt" 1 1)))
          '(diff_highlight_result 1 "same" 1 (("+late-live" (0 10 "Added"))))
          '(agent_settled #f)
        ) ;emit
        (check-true (string-contains? (chat) "History reply"))
        (check-true (string-contains? (chat) "Historical tool result"))
        (check-false (string-contains? (chat) "Turn changes"))
        (check-false (string-contains? (chat) "+1 -1"))
        (check-false (string-contains? (chat) "-live"))
        ;; History may schedule Markdown but must never enqueue a diff.
        (let ((job (chan-try-recv! (%pi-app-display-jobs app) #f)))
          (check (and job (car job)) => 'markdown_job)
          (check (and job (cadddr job)) => "History reply")
        ) ;let
        (check (chan-try-recv! (%pi-app-display-jobs app) #f) => #f)
        (check (path-read-text file) => original)
      ) ;let
    ) ;lambda
    (lambda () (when (file-exists? file) (delete-file file)) (path-rmdir tmp))
  ) ;dynamic-wind
) ;let*

(check-report)
