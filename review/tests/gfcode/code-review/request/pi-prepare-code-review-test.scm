;; pi-prepare-code-review
;; 收集变更文件并构建一次只读结构化审查所需的不可变请求数据。
;;
;; 语法
;; ----
;; (pi-prepare-code-review parsed cfg :collector collector :file-records file-records)
;;
;; 参数
;; ----
;; parsed : alist?
;; 含 messages、review-ref 和 staged 的审查参数。
;; cfg : alist?
;; 当前运行配置。
;; collector : procedure?（可选测试接缝）
;; 接收关键字参数并返回 pi-collect-changed-files 结构。
;; file-records : procedure?（可选测试接缝）
;; 接收路径列表，返回审查文件记录。
;;
;; 返回值
;; ----
;; review-result
;; status 为 ok（review-session-request）或 no-files（review-no-files）；
;; ok 时包含 paths、records、prompt 和 notice。
;;
;; 没有变更文件时不调用 file-records，返回 no-files。

(import (liii check)
  (liii string)
  (gfcode code-review request)
  (gfcode code-review result)
) ;import

(check-set-mode! 'report-failed)

(define (collected paths total)
  (list (cons 'paths paths)
    (cons 'total total)
    (cons 'message (if (> total (length paths)) "Reviewing first 10 files." #f))
  ) ;list
) ;define

(let* ((seen #f)
       (result
         (pi-prepare-code-review (list (cons 'messages '()) (cons 'review-ref "main") (cons 'staged #t))
           '()
           :collector
           (lambda opts (set! seen opts) (collected '("a.scm" "b.py") 2))
           :file-records
           (lambda (paths)
             (map (lambda (p) (list (cons 'path p) (cons 'language "scheme") (cons 'content "x")))
               paths
             ) ;map
           ) ;lambda
         ) ;pi-prepare-code-review
       ) ;result
      ) ;
  (check (review-session-request? result) => #t)
  (check (review-session-request-paths result) => '("a.scm" "b.py"))
  (check-true (string-contains? (review-session-request-prompt result) "## Files to Review")
  ) ;check-true
  (check-true (pair? (member :staged seen)))
) ;let*

(let ((called #f))
  (let ((result (pi-prepare-code-review '((messages))
                  '()
                  :collector    (lambda opts (collected '() 0))
                  :file-records (lambda (paths) (set! called #t) '())
                ) ;pi-prepare-code-review
        ) ;result
       ) ;
    (check (review-no-files? result) => #t)
    (check called => #f)
  ) ;let
) ;let

(check-report)
