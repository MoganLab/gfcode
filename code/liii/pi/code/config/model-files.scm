;;
;; Copyright (C) 2026 The Goldfish Scheme Authors
;;
;; Licensed under the MIT License
;;

;; 模型文件读取：models/<provider>/<model>.json 的定位、解析与目录枚举。
(define-library (liii pi code config model-files)
  (import (scheme base)
    (scheme file)
    (liii base)
    (liii list)
    (liii string)
    (liii os)
    (liii pi code config user-fs)
  ) ;import
  (export %model-json-name? %find-model-file-by-id %model-file
    %directory-model-ids
  ) ;export
  (begin

    ;; 目录项是否为模型 JSON 文件（以 .json 结尾且不是裸 ".json"）
    (define (%model-json-name? entry)
      (and (string-ends? entry ".json") (not (string=? entry ".json")))
    ) ;define

    ;; models/<p>/ 目录项列表；目录不存在或不可读时返回 '()
    (define (%model-dir-entries config-dir p-id)
      (let ((dir-str (pi-user-config-path config-dir "models" p-id)))
        (if (file-exists? dir-str)
          (catch #t (lambda () (vector->list (listdir dir-str))) (lambda args '()))
          '()
        ) ;if
      ) ;let
    ) ;define

    ;; 按 id 在 models/<p>/*.json 中查找模型条目；缺失返回 #f
    (define (%find-model-file-by-id config-dir p-id m-id)
      (let loop
        ((files (filter %model-json-name? (%model-dir-entries config-dir p-id))))
        (if (null? files)
          #f
          (let* ((f (car files))
                 (p (pi-user-config-path config-dir "models" p-id f))
                 (data (pi-user-read-json p))
                ) ;
            (if (and (pair? data) (equal? (pi-user-dict-ref data "id" #f) m-id))
              data
              (loop (cdr files))
            ) ;if
          ) ;let*
        ) ;if
      ) ;let
    ) ;define

    ;; 读 models/<p>/<m>.json；缺失返回 #f，语法错告警后回退按 id 查找
    (define (%model-file config-dir p-id m-id)
      (let* ((path-str (pi-user-config-path config-dir "models" p-id (string-append m-id ".json"))
             ) ;path-str
             (exists (file-exists? path-str))
             (data (and exists (pi-user-read-json path-str)))
            ) ;
        (cond ((pair? data) data)
              (exists (pi-user-warn (string-append path-str ": JSON 解析失败，已忽略该模型")
                      ) ;pi-user-warn
                #f
              ) ;exists
              (else (%find-model-file-by-id config-dir p-id m-id))
        ) ;cond
      ) ;let*
    ) ;define

    ;; 列出 models/<p>/ 下的模型 id（去 .json 后缀，保持目录顺序）
    (define (%directory-model-ids config-dir p-id)
      (map (lambda (e) (string-remove-suffix e ".json"))
        (filter %model-json-name? (%model-dir-entries config-dir p-id))
      ) ;map
    ) ;define

  ) ;begin
) ;define-library
