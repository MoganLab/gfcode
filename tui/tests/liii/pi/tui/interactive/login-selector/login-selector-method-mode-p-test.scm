;; login-selector-method-mode?
;; 判断选择器是否处于二级登录方式选择态（API Key / Kimi Code OAuth）。
;;
;; 语法
;; ----
;; (login-selector-method-mode? comp) -> boolean?
;;
;; 参数
;; ----
;; comp : login-selector?
;; 登录供应商选择器。
;;
;; 返回值
;; ----
;; boolean?
;; 选中登记了 OAuth 的 provider（kimi-coding）后为 #t；
;; Esc 返回供应商列表后为 #f。

(import (scheme base)
  (liii check)
  (liii string)
  (liii list)
  (liii tui component)
  (liii pi tui interactive login-selector)
) ;import

(check-set-mode! 'report-failed)

(define (make-sel on-method)
  (make-login-selector (lambda (p) #f)
    (lambda () #f)
    :config-dir       "/tmp/gf-nonexistent-cfg"
    :on-select-method on-method
  ) ;make-login-selector
) ;define

;; 初始为供应商列表态
(let ((sel (make-sel (lambda (p m) #f))))
  (check-false (login-selector-method-mode? sel))
  ;; 搜索 kimi 并回车：进入二级选择
  (for-each (lambda (c) (component-handle-input sel c)) '(#\k #\i #\m #\i))
  (component-handle-input sel 'enter)
  (check-true (login-selector-method-mode? sel))
  ;; Esc 返回供应商列表
  (component-handle-input sel 'escape)
  (check-false (login-selector-method-mode? sel))
) ;let

;; 二级选择：down + enter 选 OAuth；enter 直接选 API Key
(let ((picked '()))
  (let ((sel
          (make-sel
            (lambda (p m) (set! picked (cons (list p m) picked)))
          ) ;make-sel
        ) ;sel
        (type-kimi
          (lambda (s)
            (for-each (lambda (c) (component-handle-input s c)) '(#\k #\i #\m
                                                                  #\i))
          ) ;lambda
        ) ;type-kimi
       ) ;
    (type-kimi sel)
    (component-handle-input sel 'enter)
    (component-handle-input sel 'down)
    (component-handle-input sel 'enter)
    (check picked => '(("kimi-coding" "oauth")))
  ) ;let
) ;let

(let ((picked '()))
  (let ((sel (make-sel (lambda (p m) (set! picked (cons (list p m) picked))))))
    (for-each (lambda (c) (component-handle-input sel c)) '(#\k #\i #\m #\i))
    (component-handle-input sel 'enter)
    (component-handle-input sel 'enter)
    (check picked => '(("kimi-coding" "api_key")))
  ) ;let
) ;let

;; 未登记 OAuth 的 provider 不进入二级选择
(let ((selected '()))
  (let ((sel
          (make-login-selector (lambda (p) (set! selected (cons p selected)))
            (lambda () #f)
            :config-dir       "/tmp/gf-nonexistent-cfg"
            :on-select-method (lambda (p m) #f)
          ) ;make-login-selector
        ) ;sel
       ) ;
    (for-each (lambda (c) (component-handle-input sel c)) '(#\d #\e #\e #\p))
    (component-handle-input sel 'enter)
    (check-false (login-selector-method-mode? sel))
    (check selected => '("deepseek"))
  ) ;let
) ;let

(check-report)
