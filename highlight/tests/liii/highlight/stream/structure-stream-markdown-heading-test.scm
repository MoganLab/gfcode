;; structure-stream-markdown-heading
;; markdown 标题结构流集成测试：验证 markdown.json 声明的 H1–H6 单行结构。
;;
;; 语法
;; ----
;; (make-structure-stream md-def emit-event)
;; (structure-stream-feed! stream chunk)
;; (structure-stream-finish! stream)
;;
;; 参数
;; ----
;; md-def : definition?
;; markdown 语法定义（含 heading segments）。
;;
;; chunk : string
;; 任意传输块。
;;
;; 返回值
;; -----
;; 事件通过回调交付；标题独立提交，正文不并入；
;; 任意输入边界下事件序列一致。

(import (scheme base)
  (liii check)
  (liii highlight definition)
  (liii highlight stream)
) ;import

(check-set-mode! 'report-failed)

(define md-def (load-syntax-definition "markdown"))

(define (make-collector)
  (let ((box (list '())))
    (cons
      (lambda (ev) (set-car! box (cons ev (car box))))
      (lambda () (reverse (car box)))
    ) ;cons
  ) ;let
) ;define

;; 单行标题：open -> close，close 携带标题原文与 level 元数据。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "# 安装\n正文\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (cadr (car events)) => "heading-1")
    (check (caddr (car events)) => 'heading)
    (check (assoc 'level (cadddr (car events))) => '(level . 1))
    (check (list-ref (cadr events) 3) => #t)
    (check (list-ref (cadr events) 4) => "# 安装")
    ;; 标题后的正文不属于标题片段
    (check (cadr (list-ref events 2)) => "\n正文\n")
  ) ;let
) ;let*

;; H2 与 H6：级别正确；连续标题分别提交，不合并为章节。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "## 配置\n###### 附录\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content open close content))
    (check (assoc 'level (cadddr (car events))) => '(level . 2))
    (check (assoc 'level (cadddr (list-ref events 3))) => '(level . 6))
    (check (list-ref (cadr events) 4) => "## 配置")
    (check (list-ref (list-ref events 4) 4) => "###### 附录")
  ) ;let
) ;let*

;; 任意块边界：逐字符输入与整块输入事件一致；"# 安" 不提前提交。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (for-each (lambda (ch) (structure-stream-feed! s (string ch)))
    (string->list "# 安装\n正文\n")
  ) ;for-each
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (list-ref (cadr events) 4) => "# 安装")
  ) ;let
) ;let*

;; "#" 前缀在块末尾：暂存，不误判为正文；后续 " x" 补齐后打开标题。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "#")
  (check ((cdr c)) => '())
  (structure-stream-feed! s " 标题\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close content))
    (check (list-ref (cadr events) 4) => "# 标题")
  ) ;let
) ;let*

;; 无末尾换行：EOF 时标题正常闭合（closed? = #t）。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "# 无换行")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(open close))
    (check (list-ref (cadr events) 3) => #t)
    (check (list-ref (cadr events) 4) => "# 无换行")
  ) ;let
) ;let*

;; 普通文本中的 # 不打开标题（first-non-space 限制）。
(let* ((c (make-collector)) (s (make-structure-stream md-def (car c))))
  (structure-stream-feed! s "a # b\n")
  (structure-stream-finish! s)
  (let ((events ((cdr c))))
    (check (map car events) => '(content))
  ) ;let
) ;let*

(check-report)
