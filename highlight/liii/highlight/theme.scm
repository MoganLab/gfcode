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

(define-library (liii highlight theme)
  (import (scheme base) (scheme char) (liii base) (liii json) (liii string))
  (export make-theme theme? theme-name theme-revision theme-text-style
    theme-editor-color parse-theme-json default-breeze-dark-theme hex->rgb
    make-style-entry style-entry? style-entry-text-color style-entry-bg-color
    style-entry-bold? style-entry-italic? style-entry-underline?
  ) ;export
  (begin

    ;; 解析 #rrggbb 或 #aarrggbb 颜色串为 '(r g b) 整数列表
    (define (hex->rgb hex-str)
      (if (not (string? hex-str))
        #f
        (let* ((s (if (string-starts? hex-str "#") (substring hex-str 1) hex-str))
               (len (string-length s))
              ) ;
          (cond
           ((= len 6)
            (let ((r (string->number (substring s 0 2) 16))
                  (g (string->number (substring s 2 4) 16))
                  (b (string->number (substring s 4 6) 16))
                 ) ;
              (and r g b (list r g b))
            ) ;let
           ) ;
           ((= len 8)
            ;; #aarrggbb 忽略 alpha，取后 6 位 rgb
            (let ((r (string->number (substring s 2 4) 16))
                  (g (string->number (substring s 4 6) 16))
                  (b (string->number (substring s 6 8) 16))
                 ) ;
              (and r g b (list r g b))
            ) ;let
           ) ;
           (else #f)
          ) ;cond
        ) ;let*
      ) ;if
    ) ;define

    ;; 样式属性 record
    ;; text-color: '(r g b) 或 #f
    ;; background-color: '(r g b) 或 #f
    ;; bold: #t / #f
    ;; italic: #t / #f
    ;; underline: #t / #f
    (define*-record-type <style-entry>
      (make-style-entry (text-color #f)
        (background-color #f)
        (bold #f)
        (italic #f)
        (underline #f)
      ) ;make-style-entry
      style-entry?
      (text-color style-entry-text-color)
      (background-color style-entry-bg-color)
      (bold style-entry-bold?)
      (italic style-entry-italic?)
      (underline style-entry-underline?)
    ) ;define*-record-type

    ;; 主题 record
    ;; styles: alist 形式 (("Keyword" . <style-entry>) ...)
    ;; editor-colors: alist (("BackgroundColor" . '(r g b)) ...)
    (define*-record-type <theme>
      (make-theme (name "Default") (styles '()) (editor-colors '()) (revision 1))
      theme?
      (name theme-name)
      (styles theme-styles)
      (editor-colors theme-editor-colors)
      (revision theme-revision)
    ) ;define*-record-type

    ;; 查询指定 TextStyle 名（如 "Keyword"、"Normal"）的样式属性
    (define (theme-text-style th style-name)
      (let ((p (assoc style-name (theme-styles th))))
        (if p (cdr p) #f)
      ) ;let
    ) ;define

    ;; 查询指定 editor-color 名（如 "BackgroundColor"）的 '(r g b)
    (define (theme-editor-color th color-name)
      (let ((p (assoc color-name (theme-editor-colors th))))
        (if p (cdr p) #f)
      ) ;let
    ) ;define

    ;; 解析单个 text-style JSON 对象
    (define (parse-style-entry-json obj)
      (if (not (json-object? obj))
        (make-style-entry)
        (let ((tc (json-ref-string obj "text-color" #f))
              (bg (json-ref-string obj "background-color" #f))
              (b (json-ref-boolean obj "bold" #f))
              (i (json-ref-boolean obj "italic" #f))
              (u (json-ref-boolean obj "underline" #f))
             ) ;
          (make-style-entry (and tc (hex->rgb tc)) (and bg (hex->rgb bg)) b i u)
        ) ;let
      ) ;if
    ) ;define

    ;; 解析整个 theme JSON 对象（KSyntaxHighlighting .theme 规范）
    (define (parse-theme-json theme-obj)
      (let* ((meta (json-ref theme-obj "metadata"))
             (name (if (json-object? meta) (json-ref-string meta "name" "Unnamed") "Unnamed")
             ) ;name
             (rev (if (json-object? meta) (json-ref-integer meta "revision" 1) 1))
             (raw-styles (json-ref theme-obj "text-styles"))
             (styles
               (if (json-object? raw-styles)
                 (map
                   (lambda (key) (cons key (parse-style-entry-json (json-ref raw-styles key))))
                   (json-keys raw-styles)
                 ) ;map
                 '()
               ) ;if
             ) ;styles
             (raw-editor (json-ref theme-obj "editor-colors"))
             (editor-colors
               (if (json-object? raw-editor)
                 (map
                   (lambda (key)
                     (let ((v (json-ref-string raw-editor key #f)))
                       (cons key (and v (hex->rgb v)))
                     ) ;let
                   ) ;lambda
                   (json-keys raw-editor)
                 ) ;map
                 '()
               ) ;if
             ) ;editor-colors
            ) ;
        (make-theme name styles editor-colors rev)
      ) ;let*
    ) ;define

    ;; 内置 Breeze Dark 主题的精简版（开箱即用，无需从外部读文件）
    (define (default-breeze-dark-theme)
      (make-theme "Breeze Dark"
        (list (cons "Normal" (make-style-entry '(207 207 194) #f #f #f #f))
          (cons "Keyword" (make-style-entry '(207 207 194) #f #t #f #f))
          (cons "Function" (make-style-entry '(142 68 173) #f #f #f #f))
          (cons "Variable" (make-style-entry '(39 174 174) #f #f #f #f))
          (cons "ControlFlow" (make-style-entry '(253 188 75) #f #t #f #f))
          (cons "Operator" (make-style-entry '(63 128 88) #f #f #f #f))
          (cons "BuiltIn" (make-style-entry '(96 156 160) #f #f #f #f))
          (cons "Extension" (make-style-entry '(0 153 255) #f #t #f #f))
          (cons "Preprocessor" (make-style-entry '(39 174 96) #f #f #f #f))
          (cons "Attribute" (make-style-entry '(41 128 185) #f #f #f #f))
          (cons "Char" (make-style-entry '(61 174 233) #f #f #f #f))
          (cons "SpecialChar" (make-style-entry '(61 174 233) #f #f #f #f))
          (cons "String" (make-style-entry '(244 79 79) #f #f #f #f))
          (cons "VerbatimString" (make-style-entry '(218 68 83) #f #f #f #f))
          (cons "SpecialString" (make-style-entry '(218 68 83) #f #f #f #f))
          (cons "Import" (make-style-entry '(39 174 96) #f #f #f #f))
          (cons "DataType" (make-style-entry '(41 128 185) #f #f #f #f))
          (cons "DecVal" (make-style-entry '(246 116 0) #f #f #f #f))
          (cons "BaseN" (make-style-entry '(246 116 0) #f #f #f #f))
          (cons "Float" (make-style-entry '(246 116 0) #f #f #f #f))
          (cons "Constant" (make-style-entry '(39 174 174) #f #f #f #f))
          (cons "Comment" (make-style-entry '(122 136 142) #f #f #f #f))
          (cons "Documentation" (make-style-entry '(160 160 164) #f #f #f #f))
          (cons "Annotation" (make-style-entry '(63 128 88) #f #f #f #f))
          (cons "CommentVar" (make-style-entry '(127 140 141) #f #f #f #f))
          (cons "RegionMarker" (make-style-entry '(41 128 185) #f #f #f #f))
          (cons "Information" (make-style-entry '(176 176 176) #f #f #f #f))
          (cons "Warning" (make-style-entry '(218 68 83) #f #f #f #f))
          (cons "Alert" (make-style-entry '(149 165 166) '(77 33 34) #t #f #f))
          (cons "Error" (make-style-entry '(218 68 83) #f #f #f #t))
          (cons "Others" (make-style-entry '(39 174 96) #f #f #f #f))
        ) ;list
        (list (cons "BackgroundColor" '(35 38 41)) (cons "CodeFolding" '(34
                                                                         87
                                                                         116)))
        1
      ) ;make-theme
    ) ;define

  ) ;begin
) ;define-library
