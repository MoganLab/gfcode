;; pi-scan-extension-dir
;; 扫描 gfcode library 扩展目录，返回 library 扩展描述符。
;;
;; 语法
;; ----
;; (pi-scan-extension-dir dir)
;;
;; 参数
;; ----
;; dir : (or string path)
;; gfcode 扩展目录。
;;
;; 返回值
;; ----
;; list
;; 按路径字典序排列的 library 扩展描述符，包含 name、root 和 path。

(import (liii check)
  (liii list)
  (liii string)
  (liii path)
  (liii os)
  (liii pi code core extensions)
) ;import

(check-set-mode! 'report-failed)

(define (%normalized p)
  (string-replace (path->string (path-resolve (path p))) "\\" "/")
) ;define

(define (get-fixtures-dir)
  (cond ((file-exists? "tests/fixtures") "tests/fixtures")
        ((file-exists? "tools/pi/tests/fixtures") "tools/pi/tests/fixtures")
        (else "../../tools/pi/tests/fixtures")
  ) ;cond
) ;define

;; 1. 不存在的目录和普通文件安全返回空列表。
(check (pi-scan-extension-dir "/non/existent/path/for/sure/12345") => '())
(check (pi-scan-extension-dir (string-append (get-fixtures-dir) "/extensions/ignore.txt"))
  =>
  '()
) ;check

;; 2. 扫描 gfcode 目录，返回库名、搜索根和绝对路径。
(let* ((fixture-dir (string-append (get-fixtures-dir) "/gfcode"))
       (found (pi-scan-extension-dir fixture-dir))
       (valid (find (lambda (entry)
                      (equal? (cdr (assq 'name entry)) '(gfcode valid-ext1))
                    ) ;lambda
                found
              ) ;find
       ) ;valid
      ) ;
  (check-true (pair? found))
  (check-true (and valid #t))
  (check (cdr (assq 'type valid)) => 'library)
  (check (cdr (assq 'root valid))
    =>
    (%normalized (get-fixtures-dir))
  ) ;check
  (check (cdr (assq 'path valid))
    =>
    (%normalized (string-append fixture-dir "/valid-ext1.scm"))
  ) ;check
  (for-each
    (lambda (entry)
      (check (eq? (cdr (assq 'type entry)) 'library) => #t)
      (check (string=? (path-suffix (path (cdr (assq 'path entry)))) ".scm") => #t)
    ) ;lambda
    found
  ) ;for-each
) ;let*

;; 3. 空目录返回空列表。
(let ((empty-dir (string-append (get-fixtures-dir) "/empty-gfcode")))
  (catch #t (lambda () (mkdir empty-dir)) (lambda args #f))
  (check (pi-scan-extension-dir empty-dir) => '())
  (catch #t (lambda () (rmdir empty-dir)) (lambda args #f))
) ;let

(check-report)
