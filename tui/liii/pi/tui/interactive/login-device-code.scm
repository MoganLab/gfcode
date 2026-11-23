;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; device-code 展示组件（对应 pi 的 AuthEvent.type==device_code）：
;; 展示 user_code 与 verification_uri_complete，提供「打开浏览器」入口，
;; 下方显示等待授权的轮询态；Esc 取消（置 cancelled 标志，轮询循环据此中止）。
(define-library (liii pi tui interactive login-device-code)
  (export make-login-device-code login-device-code? login-device-code-cancelled?
    login-device-code-user-code login-device-code-verification-uri
    login-device-code-cursor-position login-device-code-open-browser!
  ) ;export
  (import (scheme base)
    (liii string)
    (liii unicode)
    (liii web-browser)
    (liii tui)
    (liii tui component)
  ) ;import
  (begin

    (define %accent "\x1b;[35m")
    (define %muted "\x1b;[38;2;157;165;169m")
    (define %border "\x1b;[38;2;91;127;200m")
    (define %bold "\x1b;[1m")
    (define %reset "\x1b;[0m")

    (define (%colored color text)
      (string-append color text %reset)
    ) ;define

    (define-record-type <login-device-code-state>
      (%make-login-device-code-state provider user-code verification-uri
        on-cancel cancelled? browser-opened?
      ) ;%make-login-device-code-state
      login-device-code-state?
      (provider login-device-code-state-provider)
      (user-code login-device-code-state-user-code)
      (verification-uri login-device-code-state-verification-uri)
      (on-cancel login-device-code-state-on-cancel)
      (cancelled? login-device-code-state-cancelled?
        login-device-code-state-cancelled?-set!
      ) ;cancelled?
      (browser-opened? login-device-code-state-browser-opened?
        login-device-code-state-browser-opened?-set!
      ) ;browser-opened?
    ) ;define-record-type

    (define (%state comp)
      (let ((data (component-data comp)))
        (and (pair? data) (eq? (car data) 'login-device-code) (cadr data))
      ) ;let
    ) ;define

    (define (login-device-code? obj)
      (and (component? obj) (login-device-code-state? (%state obj)))
    ) ;define

    ;; 轮询循环的 cancelled? 谓词读取此标志
    (define (login-device-code-cancelled? comp)
      (login-device-code-state-cancelled? (%state comp))
    ) ;define

    (define (login-device-code-user-code comp)
      (login-device-code-state-user-code (%state comp))
    ) ;define

    (define (login-device-code-verification-uri comp)
      (login-device-code-state-verification-uri (%state comp))
    ) ;define

    ;; 无输入行：光标停在标题行下方（与 render 布局一致）
    (define (login-device-code-cursor-position comp)
      '(4 2)
    ) ;define

    (define (login-device-code-open-browser! comp)
      (let ((state (%state comp)))
        (login-device-code-state-browser-opened?-set! state #t)
        (catch #t
          (lambda () (web-browser-open (login-device-code-state-verification-uri state)))
          (lambda args #f)
        ) ;catch
      ) ;let
    ) ;define

    (define (%render comp width)
      (let* ((state (%state comp))
             (border (%colored %border (utf8-make-string (max 1 width) #\─)))
             (title (string-append "Login to "
                      (login-device-code-state-provider state)
                      " with Kimi Code (subscription)"
                    ) ;string-append
             ) ;title
             (code-line (string-append "  Code: "
                          (%colored %bold (login-device-code-state-user-code state))
                        ) ;string-append
             ) ;code-line
             (uri (login-device-code-state-verification-uri state))
             (waiting (%colored %muted "  Waiting for authorization in browser…"))
             (opened-hint (if (login-device-code-state-browser-opened? state)
                            (%colored %muted "  Browser opened. Complete authorization there.")
                            (%colored %muted "  Browser not opened? Visit the URL above manually.")
                          ) ;if
             ) ;opened-hint
             (hint (%colored %muted "  enter to open browser · esc to cancel"))
            ) ;
        (list border
          ""
          title
          ""
          code-line
          ""
          (string-append "  " (%colored %accent uri))
          ""
          waiting
          opened-hint
          ""
          hint
        ) ;list
      ) ;let*
    ) ;define

    (define (%handle-input comp key)
      (let ((state (%state comp)))
        (case key
         ((escape ctrl-c)
          (login-device-code-state-cancelled?-set! state #t)
          ((login-device-code-state-on-cancel state))
          #t
         ) ;
         ((enter) (login-device-code-open-browser! comp) #t)
         (else #f)
        ) ;case
      ) ;let
    ) ;define

    (define (make-login-device-code provider user-code verification-uri on-cancel)
      (let* ((state (%make-login-device-code-state provider user-code
                      verification-uri on-cancel #f #f
                    ) ;%make-login-device-code-state
             ) ;state
             (comp (make-component :render %render :handle-input %handle-input))
            ) ;
        (component-data-set! comp (list 'login-device-code state))
        comp
      ) ;let*
    ) ;define

  ) ;begin
) ;define-library
