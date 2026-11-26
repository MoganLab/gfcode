;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

(define-library (gfcode code-review auto)
  (import (scheme base)
    (liii string)
    (liii list)
    (liii pi code core tools read)
    (liii pi ai message)
    (gfcode code-review language)
  ) ;import
  (export pi-build-review-injection pi-edited-files-from-tool-calls
    make-pi-review-edit-tracker pi-review-tracker? pi-review-track-tool-result!
    pi-review-tracker-end-turn! pi-review-tracker-take-edits!
  ) ;export
  (begin

    (define (%field key entry default)
      (let ((pair (assoc key entry)))
        (if pair (cdr pair) default)
      ) ;let
    ) ;define

    (define (%block-value key alt-key blk default)
      (cond
       ((pi-tool-call-block? blk)
        (cond ((or (equal? key "name") (equal? alt-key 'name)) (pi-tool-call-block-name blk))
              ((or (equal? key "arguments") (equal? alt-key 'arguments))
               (pi-tool-call-block-arguments blk)
              ) ;
              ((or (equal? key "id") (equal? alt-key 'id)) (pi-tool-call-block-id blk))
              ((or (equal? key "thought-signature") (equal? alt-key 'thought-signature))
               (pi-tool-call-block-thought-signature blk)
              ) ;
              (else default)
        ) ;cond
       ) ;
       ((list? blk)
        (let ((pair (or (assoc key blk) (assoc alt-key blk))))
          (if (pair? pair) (cdr pair) default)
        ) ;let
       ) ;
       ((let? blk)
        (let ((sym (if (symbol? alt-key) alt-key (string->symbol key))))
          (if (defined? sym blk) (blk sym) default)
        ) ;let
       ) ;
       (else default)
      ) ;cond
    ) ;define

    (define (%languages files)
      (let loop
        ((rest files) (acc '()))
        (cond ((null? rest) (reverse acc))
              (else
                (let ((lang (%field 'language (car rest) #f)))
                  (if (and lang (not (member lang acc)))
                    (loop (cdr rest) (cons lang acc))
                    (loop (cdr rest) acc)
                  ) ;if
                ) ;let
              ) ;else
        ) ;cond
      ) ;let
    ) ;define

    (define (%file-list files)
      (string-join (map (lambda (f) (%field 'path f "")) files) ", ")
    ) ;define

    (define (pi-build-review-injection files)
      (if (null? files)
        #f
        (string-append "\n\n## Code Review\n\n"
          "You edited: "
          (%file-list files)
          ". Before proceeding, briefly verify:"
          (pi-build-language-section (%languages files))
          "\n\nFix any issues found, then continue."
        ) ;string-append
      ) ;if
    ) ;define

    (define (%tool-name call)
      (%block-value "name" 'name call "")
    ) ;define

    (define (%tool-args call)
      (let ((args (%block-value "arguments" 'arguments call '())))
        (if (pair? args) args '())
      ) ;let
    ) ;define

    (define (%edited-path call)
      (let* ((name (%tool-name call)) (args (%tool-args call)))
        (if (or (string=? name "write") (string=? name "edit"))
          (let ((path (or (pi-arg-ref args "path" #f) (pi-arg-ref args "file_path" #f))))
            (and (string? path) (not (string-null? (string-trim-both path))) path)
          ) ;let
          #f
        ) ;if
      ) ;let*
    ) ;define

    (define (%has-path? files path)
      (any (lambda (f) (string=? (%field 'path f "") path)) files)
    ) ;define

    (define (%push-edited files path)
      (if (%has-path? files path)
        files
        (append files
          (list (list (cons 'path path) (cons 'language (pi-detect-language path))))
        ) ;append
      ) ;if
    ) ;define

    (define-record-type <pi-review-edit-tracker>
      (%make-review-edit-tracker current snapshot)
      pi-review-tracker?
      (current %tracker-current %tracker-current-set!)
      (snapshot %tracker-snapshot %tracker-snapshot-set!)
    ) ;define-record-type

    (define (make-pi-review-edit-tracker)
      (%make-review-edit-tracker '() #f)
    ) ;define

    ;; 工具执行结束事件：只接受成功的 write/edit，路径取自执行参数；
    ;; 未知语言文件保留（language 为 #f），与 pi-edited-files-from-tool-calls 一致
    (define (pi-review-track-tool-result! tracker payload)
      (let* ((name (%field 'name payload ""))
             (failed (%field 'isError payload #f))
             (input (%field 'input payload '()))
             (path (and (or (string=? name "write") (string=? name "edit"))
                     (not failed)
                     (pair? input)
                     (or (pi-arg-ref input "path" #f) (pi-arg-ref input "file_path" #f))
                   ) ;and
             ) ;path
            ) ;
        (when (and (string? path) (not (string-null? (string-trim-both path))))
          (%tracker-current-set! tracker (%push-edited (%tracker-current tracker) path))
        ) ;when
      ) ;let*
    ) ;define

    ;; turn 结束：把本轮累积编辑固化为快照；无编辑时清空旧快照
    (define (pi-review-tracker-end-turn! tracker turn-index)
      (let ((files (%tracker-current tracker)))
        (%tracker-snapshot-set! tracker
          (if (null? files)
            #f
            (list (cons 'files files) (cons 'turnIndex turn-index))
          ) ;if
        ) ;%tracker-snapshot-set!
        (%tracker-current-set! tracker '())
      ) ;let
    ) ;define

    ;; 读取并清空快照：同一批编辑只注入一次
    (define (pi-review-tracker-take-edits! tracker)
      (let ((snapshot (%tracker-snapshot tracker)))
        (%tracker-snapshot-set! tracker #f)
        snapshot
      ) ;let
    ) ;define

    (define (pi-edited-files-from-tool-calls tool-calls)
      (let loop
        ((rest tool-calls) (acc '()))
        (if (null? rest)
          acc
          (let ((path (%edited-path (car rest))))
            (if path (loop (cdr rest) (%push-edited acc path)) (loop (cdr rest) acc))
          ) ;let
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
