;; verbose 思考状态展示
;; 在 verbose 模式下，思考（reasoning）阶段以 🧠 emoji 给出三种状态：
;;   - thinking_start → “🧠 开始思考…”
;;   - thinking_delta → 不显示思考内容；距上次进度行 ≥ 60s 时打印
;;     “🧠 仍在思考…（已 Ns）”
;;   - thinking_end → “🧠 思考完成（用时 Ns）”
;; 思考内容本身从不打印，避免泄露模型内部推理。
;;
;; 语法
;; ----
;; (verbose-thinking-ping-due? elapsed-ms)
;;
;; 参数
;; ----
;; elapsed-ms : number?
;; 距上次进度行的毫秒数。
;;
;; 返回值
;; ----
;; boolean?
;; 是否到达 60s 进度提示阈值。

(import (scheme base)
  (liii check)
  (liii string)
  (liii json)
  (liii pi code modes verbose)
) ;import

(check-set-mode! 'report-failed)

;; 1. verbose-thinking-ping-due? 阈值边界
(check (verbose-thinking-ping-due? 0) => #f)
(check (verbose-thinking-ping-due? 59999) => #f)
(check (verbose-thinking-ping-due? 60000) => #t)
(check (verbose-thinking-ping-due? 120000) => #t)

;; 2. thinking_start 输出 🧠 开始思考，且不打印任何思考内容
(let* ((tb (list 0 "" #f (vector #f 0 0)))
       (start (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_start\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;start
       (out (with-output-to-string (lambda () (display-agent-event start "" tb))))
      ) ;
  (check (string-contains? out "🧠 开始思考") => #t)
  (check-true (not (string-contains? out "仍在思考")))
) ;let*

;; 3. thinking_delta 短间隔不输出进度行；内容不打印
(let* ((tb (list 0 "" #f (vector #f 0 0)))
       (start (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_start\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;start
       (delta (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_delta\",\"delta\":\"秘密推理内容\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;delta
      ) ;
  (display-agent-event start "" tb)
  (let ((out (with-output-to-string (lambda () (display-agent-event delta "" tb)))))
    ;; 刚开始思考，立即的 delta 不应触发 60s 进度行
    (check-true (not (string-contains? out "仍在思考")))
    ;; 思考内容绝不输出
    (check-true (not (string-contains? out "秘密推理内容")))
  ) ;let
) ;let*

;; 4. thinking_end 输出 🧠 思考完成，并复位思考状态
(let* ((tb (list 0 "" #f (vector #f 0 0)))
       (start (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_start\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;start
       (tend (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_end\",\"contentIndex\":0}}"
             ) ;string->json
       ) ;tend
      ) ;
  (display-agent-event start "" tb)
  (let ((out (with-output-to-string (lambda () (display-agent-event tend "" tb)))))
    (check (string-contains? out "🧠 思考完成") => #t)
  ) ;let
  ;; 结束后 active 复位为 #f
  (check (vector-ref (cadddr tb) 0) => #f)
) ;let*

;; 5. 思考未正常结束时，message_end 兜底收尾输出 🧠 思考完成
(let* ((tb (list 0 "" #f (vector #f 0 0)))
       (start (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_start\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;start
       (mend (string->json "{\"type\":\"message_end\",\"message\":{\"role\":\"assistant\"}}")
       ) ;mend
      ) ;
  (display-agent-event start "" tb)
  (let ((out (with-output-to-string (lambda () (display-agent-event mend "" tb)))))
    (check (string-contains? out "🧠 思考完成") => #t)
  ) ;let
  (check (vector-ref (cadddr tb) 0) => #f)
) ;let*

;; 6. 新 turn_start 重置上一轮残留的思考状态
(let* ((tb (list 1 "" #f (vector #t 1000 1000)))
       (turn (string->json "{\"type\":\"turn_start\"}"))
      ) ;
  (display-agent-event turn "" tb)
  (check (car tb) => 2)
  (check (vector-ref (cadddr tb) 0) => #f)
  (check (vector-ref (cadddr tb) 1) => 0)
  (check (vector-ref (cadddr tb) 2) => 0)
) ;let*

;; 7. 思考结束后随后的 text_delta 在 message_end 时正常显示为 💬 消息
(let* ((tb (list 0 "" #f (vector #f 0 0)))
       (start (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_start\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;start
       (tend (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_end\",\"contentIndex\":0}}"
             ) ;string->json
       ) ;tend
       (text (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"text_delta\",\"delta\":\"最终答复\"}}"
             ) ;string->json
       ) ;text
       (mend (string->json "{\"type\":\"message_end\",\"message\":{\"role\":\"assistant\"}}")
       ) ;mend
      ) ;
  (display-agent-event start "" tb)
  (display-agent-event tend "" tb)
  (display-agent-event text "" tb)
  (let ((out (with-output-to-string (lambda () (display-agent-event mend "" tb)))))
    (check (string-contains? out "💬 最终答复") => #t)
  ) ;let
) ;let*

;; 8. 惰性补齐：turn-box 仅含轮次时仍能正常跟踪思考状态
;;    回归旧 ensure-message-slots 在 turn-box 元素不足时把思考盒置为 #f 的 bug
(let* ((tb (list 0))
       (turn (string->json "{\"type\":\"turn_start\"}"))
       (start (string->json "{\"type\":\"message_update\",\"assistantMessageEvent\":{\"type\":\"thinking_start\",\"contentIndex\":0}}"
              ) ;string->json
       ) ;start
      ) ;
  ;; 先触发 turn_start 惰性补齐槽位
  (display-agent-event turn "" tb)
  ;; 思考盒应已被补齐为 vector，而非 #f
  (check-true (vector? (cadddr tb)))
  ;; 随后 thinking_start 能正常记录 active 状态
  (display-agent-event start "" tb)
  (check (vector-ref (cadddr tb) 0) => #t)
  ;; 消息缓冲槽也应被补齐为空字符串
  (check (cadr tb) => "")
  (check (caddr tb) => #f)
) ;let*

(check-report)
