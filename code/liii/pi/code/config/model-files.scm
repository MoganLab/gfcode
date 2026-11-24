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
    (liii path)
    (liii path stat)
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

    ;; path 是否为目录（先要求存在，避免对缺失路径取 stat）
    (define (%dir? p)
      (and (file-exists? p) (path-stat-dir? (path-stat p)))
    ) ;define

    ;; 递归收集 models/<p>/ 下所有 .json 文件的相对路径（相对 models/<p>/，
    ;; 保留 .json 后缀与中间子目录斜杠），跳过 . 与 ..
    (define (%collect-model-files dir prefix)
      (let ((entries
              (catch #t (lambda () (vector->list (listdir dir))) (lambda args '()))
            ) ;entries
           ) ;
        (apply append
          (map
            (lambda (e)
              (cond ((or (string=? e ".") (string=? e "..")) '())
                    (else
                      (let ((full (string-append dir "/" e)))
                        (cond ((%dir? full) (%collect-model-files full (string-append prefix e "/")))
                              ((%model-json-name? e) (list (string-append prefix e)))
                              (else '())
                        ) ;cond
                      ) ;let
                    ) ;else
              ) ;cond
            ) ;lambda
            entries
          ) ;map
        ) ;apply
      ) ;let
    ) ;define

    ;; 按 id 在 models/<p>/ 下（含子目录）查找模型条目；缺失返回 #f
    (define (%find-model-file-by-id config-dir p-id m-id)
      (let ((dir-str (pi-user-config-path config-dir "models" p-id)))
        (let loop
          ((files (if (file-exists? dir-str) (%collect-model-files dir-str "") '())))
          (if (null? files)
            #f
            (let* ((rel (car files))
                   (p (pi-user-config-path config-dir "models" p-id rel))
                   (data (pi-user-read-json p))
                  ) ;
              (if (and (pair? data) (equal? (pi-user-dict-ref data "id" #f) m-id))
                data
                (loop (cdr files))
              ) ;if
            ) ;let*
          ) ;if
        ) ;let
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

    ;; 列出 models/<p>/ 下的模型 id（递归子目录，去 .json 后缀，
    ;; 保留子目录斜杠，使含斜杠 id 的模型文件也能被目录枚举发现）
    (define (%directory-model-ids config-dir p-id)
      (let ((dir-str (pi-user-config-path config-dir "models" p-id)))
        (if (file-exists? dir-str)
          (map (lambda (rel) (string-remove-suffix rel ".json"))
            (%collect-model-files dir-str "")
          ) ;map
          '()
        ) ;if
      ) ;let
    ) ;define

  ) ;begin
) ;define-library
