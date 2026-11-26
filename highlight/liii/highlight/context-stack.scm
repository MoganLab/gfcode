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
;; distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
;; WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
;; License for the specific language governing permissions and limitations
;; under the License.
;;

;; 高亮上下文栈切换与栈顶查询工具。
;; 这些函数只操作纯上下文名栈与 include 帧，不构造/读取高亮状态机记录，
;; 从 (liii highlight highlighter) 拆出，使主模块控制在行数上限内。

(define-library (liii highlight context-stack)
  (import (scheme base) (liii base) (liii highlight definition))
  (export apply-context-switch apply-context-switch-simple
    apply-context-switch-host %include-frame? %top-context
  ) ;export
  (begin

    ;; 执行上下文切换
    ;; ctx-target: '(stay) | '(push "Name") | '(pop N) | '(pop N "Target")
    ;; stack: 顶层可能是普通字符串上下文名，也可能是 include 帧
    ;;   (include <sub-def> <inner-stack>)
    (define (apply-context-switch stack target def)
      (cond
       ((and (pair? stack) (pair? (car stack)) (eq? (caar stack) 'include))
        ;; 顶层在 include 帧内：对 inner-stack 应用切换
        (let* ((frame (car stack))
               (sub-def (cadr frame))
               (inner (caddr frame))
               (new-inner (apply-context-switch-inner inner target sub-def))
              ) ;
          (if (null? new-inner)
            ;; inner 栈弹空：丢弃 include 帧，回到外层
            (if (null? (cdr stack))
              (list (definition-initial-context-name def))
              (cdr stack)
            ) ;if
            (cons (list 'include sub-def new-inner (cadddr frame) (car (cddddr frame)))
              (cdr stack)
            ) ;cons
          ) ;if
        ) ;let*
       ) ;
       (else (apply-context-switch-simple stack target def))
      ) ;cond
    ) ;define

    ;; 对普通（纯上下文名字符串）栈应用切换
    (define (apply-context-switch-simple stack target def)
      (case (car target)
            ((stay) stack)
            ((push) (cons (cadr target) stack))
            ((pop)
             (let* ((count (cadr target))
                    (target-name (if (> (length target) 2) (caddr target) #f))
                    ;; 弹出 count 个，但保证至少保留底层的初始上下文
                    (popped
                      (let loop
                        ((s stack) (n count))
                        (if (or (<= n 0) (null? (cdr s))) s (loop (cdr s) (- n 1)))
                      ) ;let
                    ) ;popped
                   ) ;
               (if target-name (cons target-name popped) popped)
             ) ;let*
            ) ;
            (else stack)
      ) ;case
    ) ;define

    ;; 对 include 帧内部的 inner-stack 应用切换（inner-stack 全是字符串）
    (define (apply-context-switch-inner inner target sub-def)
      (case (car target)
            ((stay) inner)
            ((push) (cons (cadr target) inner))
            ((pop)
             (let* ((count (cadr target))
                    (target-name (if (> (length target) 2) (caddr target) #f))
                    (popped
                      (let loop
                        ((s inner) (n count))
                        (if (or (<= n 0) (null? s)) s (loop (cdr s) (- n 1)))
                      ) ;let
                    ) ;popped
                   ) ;
               (if (and target-name (not (null? popped))) (cons target-name popped) popped)
             ) ;let*
            ) ;
            (else inner)
      ) ;case
    ) ;define

    ;; 宿主规则命中时使用：宿主规则在 include 帧内命中意味着要离开子语言，
    ;; 因此始终丢弃 include 帧，对外层栈应用切换。
    (define (apply-context-switch-host stack target def)
      (let* ((frame? (and (pair? stack) (pair? (car stack)) (eq? (caar stack) 'include)))
             (outer (if frame? (cdr stack) stack))
             (new-outer (apply-context-switch-simple outer target def))
            ) ;
        (if (null? new-outer) (list (definition-initial-context-name def)) new-outer)
      ) ;let*
    ) ;define

    (define (%include-frame? x)
      (and (pair? x) (eq? (car x) 'include))
    ) ;define

    ;; 取栈顶上下文与对应 def（处理 include 帧）
    ;; 返回 (values cur-ctx effective-def)
    (define (%top-context stack def)
      (let ((top (car stack)))
        (if (%include-frame? top)
          (let* ((sub-def (cadr top))
                 (inner (caddr top))
                 (inner-top (if (null? inner) #f (car inner)))
                 (inner-ctx (if inner-top (definition-find-context sub-def inner-top) #f))
                ) ;
            (values inner-ctx sub-def)
          ) ;let*
          (values (definition-find-context def top) def)
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
