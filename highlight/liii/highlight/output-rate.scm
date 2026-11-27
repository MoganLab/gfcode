;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;; http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.
;;

(define-library (liii highlight output-rate)
  (import (scheme base) (scheme time) (liii base) (liii time) (liii string))
  (export make-rate-limited-sink rate-limited-sink? rate-limited-sink-write!
    rate-limited-sink-set-rate! rate-limited-sink-flush!
    rate-limited-sink-write-units!
  ) ;export
  (begin

    ;; 运行时可调速的输出 sink：token bucket 限流。
    ;; rate：每秒输出的字符单元数；#f 表示不限速。
    ;; burst：桶容量（瞬时允许的输出量）。
    ;; clock / sleep 可注入，测试用虚拟时间，不实际等待。
    ;; 只控制时间节奏，不改变文本内容、不切断 UTF-8 字符与 ANSI 转义序列。

    (define (%default-clock)
      ;; current-second 来自 (liii time)，系统时钟精度秒级浮点。
      (current-second)
    ) ;define

    (define (%default-sleep seconds)
      (if (> seconds 0) (sleep seconds))
    ) ;define

    (define*-record-type <rate-limited-sink>
      (make-rate-limited-sink out
        (rate #f)
        (burst 80)
        (clock %default-clock)
        (sleep-fn %default-sleep)
        (tokens burst)
        (last-time #f)
      ) ;make-rate-limited-sink
      rate-limited-sink?
      (out sink-out)
      (rate sink-rate set-sink-rate!)
      (burst sink-burst)
      (clock sink-clock)
      (sleep-fn sink-sleep-fn)
      (tokens sink-tokens set-sink-tokens!)
      (last-time sink-last-time set-sink-last-time!)
    ) ;define*-record-type

    ;; 当前令牌数：按经过时间补充，通常封顶 burst。
    ;; 等待一个大于 burst 的语义单元时允许累加到该单元大小，否则永远无法写出。
    (define (%refill! sink now cap)
      (let ((last (sink-last-time sink)) (rate (sink-rate sink)))
        (if (not last)
          ;; 首次只初始化计时；令牌由构造器或 set-rate! 设定，不重置。
          (set-sink-last-time! sink now)
          (let* ((elapsed (max 0 (- now last)))
                 (current (min cap (+ (sink-tokens sink) (* elapsed rate))))
                ) ;
            (set-sink-last-time! sink now)
            (set-sink-tokens! sink current)
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    ;; 取当前令牌（不修改）；可选 target 用于大语义单元的等待。
    (define (%available sink . target)
      (let ((now ((sink-clock sink)))
            (cap (if (null? target) (sink-burst sink) (max (sink-burst sink) (car target))))
           ) ;
        (%refill! sink now cap)
        (sink-tokens sink)
      ) ;let
    ) ;define

    ;; 动态调速：新速率立即生效。
    (define (rate-limited-sink-set-rate! sink rate)
      (if
        (and rate (or (not (number? rate)) (<= rate 0)))
        (error 'output-rate-error "Rate must be a positive number or #f" rate)
      ) ;if
      (set-sink-rate! sink rate)
      ;; 重置令牌与计时：新 burst 额度立即生效；
      ;; 从有限速率切到 #f 立即排空，反向切换重新计额度。
      (set-sink-last-time! sink #f)
      (set-sink-tokens! sink (sink-burst sink))
    ) ;define

    ;; 若批次末尾落在 CSI/SGR 转义序列中间，扩展到完整序列。
    ;; Scheme 按字符索引字符串，因此按字符批次写出也不会切断 UTF-8 字符。
    (define (%ansi-safe-length text n)
      (let ((len (string-length text)))
        (let loop
          ((i 0))
          (if (>= i n)
            n
            (if
              (and (< (+ i 1) len)
                (char=? (string-ref text i) (integer->char 27))
                (char=? (string-ref text (+ i 1)) #\[)
              ) ;and
              (let escape
                ((j (+ i 2)))
                (cond ((>= j len) len)
                      ((char=? (string-ref text j) #\m) (if (< n (+ j 1)) (+ j 1) (loop (+ j 1))))
                      (else (escape (+ j 1)))
                ) ;cond
              ) ;let
              (loop (+ i 1))
            ) ;if
          ) ;if
        ) ;let
      ) ;let
    ) ;define

    ;; 输出一段文本：按当前速率分小批写出，每批之间检查最新速率。
    ;; 写出当前可用的一批，返回剩余文本。
    (define (%write-batch sink rest avail)
      (let* ((requested
               (min (string-length rest) (max 1 (exact (floor avail))))
             ) ;requested
             (n (%ansi-safe-length rest requested))
             (piece (substring rest 0 n))
            ) ;
        (display piece (sink-out sink))
        (set-sink-tokens! sink (- (sink-tokens sink) n))
        (substring rest n (string-length rest))
      ) ;let*
    ) ;define

    (define (rate-limited-sink-write! sink text)
      (let loop
        ((rest text))
        (cond ((string-null? rest) #t)
              ((not (sink-rate sink)) (display rest (sink-out sink)) #t)
              ((< (%available sink) 1)
               ;; 等待到至少 1 个字符的时间；期间速率可能被外部修改。
               ((sink-sleep-fn sink) (/ (- 1 (%available sink)) (sink-rate sink)))
               (loop rest)
              ) ;
              (else (loop (%write-batch sink rest (%available sink))))
        ) ;cond
      ) ;let
    ) ;define

    ;; 按计费单元等待：units 为本次输出的计费数量（字符数或 1 个结构）。
    (define (%wait-units! sink units)
      (let loop
        ()
        (if (and (sink-rate sink) (< (%available sink units) units))
          (begin
           ((sink-sleep-fn sink)
            (if (sink-rate sink) (/ (- units (%available sink units)) (sink-rate sink)) 0)
           ) ;
           (loop)
          ) ;begin
        ) ;if
      ) ;let
    ) ;define

    ;; 按语义单元计费写出：units 为计费数量（字符数或 1 个结构片段）。
    ;; 不限速时立即写出；限速时先按 units 等待额度，再一次写出整段。
    (define (rate-limited-sink-write-units! sink text units)
      (if (not (sink-rate sink))
        (display text (sink-out sink))
        (begin
          (%wait-units! sink units)
          (display text (sink-out sink))
          (set-sink-tokens! sink (- (sink-tokens sink) units))
        ) ;begin
      ) ;if
    ) ;define

    (define (rate-limited-sink-flush! sink)
      (flush-output-port (sink-out sink))
    ) ;define

  ) ;begin
) ;define-library
