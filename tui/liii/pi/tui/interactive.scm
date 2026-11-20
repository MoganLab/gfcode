;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (liii pi tui interactive)
  (export make-pi-header pi-header? make-pi-footer pi-footer?
    pi-footer-model-label pi-footer-set-thinking-level! pi-footer-branch
    pi-footer-set-branch! pi-footer-set-active-node! make-pi-app pi-app?
    pi-app-screen pi-app-editor pi-app-render! pi-app-run pi-app-queue
    pi-app-chat pi-app-submit! pi-app-submit-initial! pi-app-drain-queue!
    pi-app-add-user-message! pi-app-add-tool-result! pi-app-add-assistant-text!
    pi-app-add-retry-message! pi-app-jobs-chan pi-app-event-chan
    pi-app-poll-events! pi-app-thinking-level pi-app-supports-thinking?
    pi-app-cycle-thinking! pi-next-thinking-level pi-app-toggle-tool-output!
    pi-app-active-selector pi-app-default-thinking-level
    pi-thinking-border-color make-user-card make-tool-card make-assistant-card
    make-queued-card make-retry-card status-card? apply-card-bg
    make-tui-agent-handler pi-app-scroll-view pi-app-scroll-up!
    pi-app-scroll-down! pi-app-scroll-top! pi-app-scroll-bottom!
    pi-app-scroll-line-up! pi-app-scroll-line-down! pi-app-frame-lines
    pi-app-handle-mouse! pi-app-steering-chan pi-app-follow-up-chan
    %pi-app-steering-pending %pi-app-follow-up-pending pi-app-queue-steering!
    pi-app-queue-follow-up! pi-app-remove-pending-message!
    pi-app-restore-queues! pi-app-toggle-thinking! pi-app-hide-thinking?
  ) ;export
  (import (liii pi tui interactive header)
    (liii pi tui interactive footer)
    (liii pi tui interactive thinking)
    (liii pi tui interactive state)
    (liii pi tui interactive app)
    (liii pi tui interactive app-events)
    (liii pi tui interactive run)
    (liii pi tui interactive views)
    (liii pi tui interactive status-card)
    (liii pi tui interactive handler)
  ) ;import
) ;define-library
