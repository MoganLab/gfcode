;; extension
;; tps 扩展工厂：注册 agent_start / agent_end 事件钩子，累加 assistant 消息 usage，
;; 运行结束时输出 TPS 行（ctx notify 优先，回退 stderr）。本文件验证加载与统计输出。
;;
;; 语法
;; ----
;; (extension api . opt-context)
;;
;; 参数
;; ----
;; api : extension-api?
;; 扩展宿主 API 实例。
;;
;; opt-context : extension-context（可选）
;; 扩展上下文。
;;
;; 返回值
;; ----
;; string?
;; 加载标记 "tps-loaded"。

(import (scheme base)
  (liii check)
  (liii path)
  (liii string)
  (liii pi ai time)
  (liii pi ai message)
  (liii pi code core extensions)
  (liii pi code core extension-notify)
  (liii pi code core extensions loader)
  (liii pi code modes output)
) ;import

(check-set-mode! 'report-failed)

(define (get-tps-path)
  (let ((test-path (path-resolve "tests/gfcode/tps/extension-test.scm")))
    (path->string
      (path-resolve
        (path-join
          (path-parent (path-parent (path-parent (path-parent test-path))))
          "gfcode"
          "tps.scm"
        ) ;path-join
      ) ;path-resolve
    ) ;path->string
  ) ;let
) ;define

;; 把 *stderr* 重定向到字符串端口，跑完 start/end 后取回捕获文本。

(define (capture-tps-line api messages)
  (let ((cap (open-output-string)))
    (when (defined? '*stderr*)
      (set! *stderr* cap)
    ) ;when
    (pi-emit! api 'agent_start '())
    (pi-emit! api 'agent_end (list (cons 'messages messages)))
    (get-output-string cap)
  ) ;let
) ;define

;; 1. 加载 tps.scm 扩展
(let* ((api (make-extension-api)) (res (pi-load-extension (get-tps-path) api)))
  (check (pair? res) => #t)
  (check (eq? (cdr (assq 'status res)) 'ok) => #t)

  ;; 2. dict 形态的 assistant 消息：累加 usage 并输出 TPS 行
  (let* ((fake-msg
           (list (cons 'role "assistant")
             (cons 'usage
               (list (cons 'input 848)
                 (cons 'output 414)
                 (cons 'cacheRead 15808)
                 (cons 'cacheWrite 0)
                 (cons 'totalTokens 17070)
               ) ;list
             ) ;cons
           ) ;list
         ) ;fake-msg
         (line (capture-tps-line api (list fake-msg)))
        ) ;
    (check-true (string-contains? line "TPS"))
    (check-true (string-contains? line "out 414"))
    (check-true (string-contains? line "in 848"))
    (check-true (string-contains? line "cache r/w 15.8K/0"))
    (check-true (string-contains? line "total 17.1K"))
  ) ;let*

  ;; 3. record 形态的 assistant 消息：pi-assistant-message 携带 usage
  (let* ((rec (pi-assistant-message (vector (pi-text-block "hi"))
                :usage
                (list (cons 'input 100)
                  (cons 'output 50)
                  (cons 'cacheRead 0)
                  (cons 'cacheWrite 0)
                  (cons 'totalTokens 150)
                ) ;list
              ) ;pi-assistant-message
         ) ;rec
         (line (capture-tps-line api (list rec)))
        ) ;
    (check-true (string-contains? line "out 50"))
    (check-true (string-contains? line "in 100"))
    (check-true (string-contains? line "total 150"))
  ) ;let*

  ;; 4. usage 值为字符串（持久化形态）也能正确累加
  (let* ((fake-msg
           (list (cons 'role "assistant")
             (cons 'usage
               (list (cons 'input "1000")
                 (cons 'output "200")
                 (cons 'cacheRead "0")
                 (cons 'cacheWrite "0")
                 (cons 'totalTokens "1200")
               ) ;list
             ) ;cons
           ) ;list
         ) ;fake-msg
         (line (capture-tps-line api (list fake-msg)))
        ) ;
    (check-true (string-contains? line "out 200"))
    (check-true (string-contains? line "in 1.0K"))
  ) ;let*

  ;; 5. 多条 assistant 消息累加
  (let* ((m1
           (list (cons 'role "assistant")
             (cons 'usage
               (list (cons 'input 10)
                 (cons 'output 20)
                 (cons 'cacheRead 0)
                 (cons 'cacheWrite 0)
                 (cons 'totalTokens 30)
               ) ;list
             ) ;cons
           ) ;list
         ) ;m1
         (m2
           (list (cons 'role "assistant")
             (cons 'usage
               (list (cons 'input 5)
                 (cons 'output 7)
                 (cons 'cacheRead 0)
                 (cons 'cacheWrite 0)
                 (cons 'totalTokens 12)
               ) ;list
             ) ;cons
           ) ;list
         ) ;m2
         (line (capture-tps-line api (list m1 m2)))
        ) ;
    (check-true (string-contains? line "out 27"))
    (check-true (string-contains? line "in 15"))
  ) ;let*

  ;; 6. 无 assistant 消息（output=0）时不输出 TPS 行
  (let* ((user-msg (list (cons 'role "user") (cons 'content "hi")))
         (line (capture-tps-line api (list user-msg)))
        ) ;
    (check (string=? (string-trim-both line) "") => #t)
  ) ;let*

  ;; 7. 非 assistant 消息被过滤：混入 user 消息不影响累加
  (let* ((asst
           (list (cons 'role "assistant")
             (cons 'usage
               (list (cons 'input 848)
                 (cons 'output 414)
                 (cons 'cacheRead 15808)
                 (cons 'cacheWrite 0)
                 (cons 'totalTokens 17070)
               ) ;list
             ) ;cons
           ) ;list
         ) ;asst
         (user-msg (list (cons 'role "user") (cons 'content "hi")))
         (line (capture-tps-line api (list user-msg asst user-msg)))
        ) ;
    (check-true (string-contains? line "out 414"))
    (check-true (string-contains? line "in 848"))
  ) ;let*

  ;; 8. notify 注入点已 arm 时：TPS 行走 ctx notify，不再写 stderr
  (let* ((captured #f) (notify-fn (lambda (msg) (set! captured msg) #t)))
    (pi-extension-notify-set! notify-fn)
    (let* ((fake-msg
             (list (cons 'role "assistant")
               (cons 'usage
                 (list (cons 'input 848)
                   (cons 'output 414)
                   (cons 'cacheRead 15808)
                   (cons 'cacheWrite 0)
                   (cons 'totalTokens 17070)
                 ) ;list
               ) ;cons
             ) ;list
           ) ;fake-msg
           (stderr-cap (open-output-string))
          ) ;
      (when (defined? '*stderr*)
        (set! *stderr* stderr-cap)
      ) ;when
      (pi-emit! api 'agent_start '())
      (pi-emit! api 'agent_end (list (cons 'messages (list fake-msg))))
      (check-true (and captured (string-contains? captured "TPS")))
      (check-true (string-contains? captured "out 414"))
      ;; notify 已消费消息，stderr 不应被写入
      (check (string=? (get-output-string stderr-cap) "") => #t)
    ) ;let*
    (pi-extension-notify-reset!)
  ) ;let*

) ;let*

(check-report)
