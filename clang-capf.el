;;; clang-capf.el --- Completion-at-point backend for c/c++ using clang -*- lexical-binding: t -*-

;; Author: Philip K. <philipk [at] posteo [dot] net>
;; Version: 1.2.3
;; Keywords: c, abbrev, convenience
;; Package-Requires: ((emacs "24.4"))
;; URL: https://git.sr.ht/~pkal/clang-capf

;; This file is NOT part of Emacs.
;;
;; This file is in the public domain, to the extent possible under law,
;; published under the CC0 1.0 Universal license.
;;
;; For a full copy of the CC0 license see
;; https://creativecommons.org/publicdomain/zero/1.0/legalcode

;;; Commentary:
;;
;; Emacs built-in `completion-at-point' completion mechanism doesn't
;; support C in any meaningful by default, which this package tries to
;; remedy, by using clang's completion mechanism.  Hence this package
;; requires clang to be installed (see `clang-capf-clang') .
;;
;; If a header file is not automatically found or in the default path,
;; extending `clang-capf-include-paths' or `clang-capf-extra-flags' might
;; help.
;;
;; `clang-capf' is based on/inspired by:
;; - https://opensource.apple.com/source/lldb/lldb-167.2/llvm/tools/clang/utils/clang-completion-mode.el.auto.html
;; - https://github.com/company-mode/company-mode/blob/master/company-clang.el
;; - https://github.com/brianjcj/auto-complete-clang/blob/master/auto-complete-clang.el
;; - https://www.reddit.com/r/vim/comments/2wf3cn/basic_clang_autocompletion_query/
;; - https://foicica.com/wiki/cpp-clang-completion

;;; Code:

(eval-when-compile (require 'rx))

(defgroup clang-capf nil
  "Completion back-end for C using clang."
  :group 'completion
  :prefix "clang-capf-")

(defcustom clang-capf-clang "clang"
  "Path to clang binary."
  :safe #'stringp
  :type 'file)

(defcustom clang-capf-include-paths
  (with-temp-buffer
    (call-process clang-capf-clang nil t nil "-E" "-x" "c++" "-" "-v")
    (goto-char (point-min))
    (search-forward-regexp
     (rx bol "#include <...> search starts here:" eol))
    (let ((start (point)) files)
      (search-forward-regexp
       (rx bol "End of search list." eol))
      (while (progn
               (forward-line -1)
               (< start (point)))
        (back-to-indentation)
        (push (buffer-substring (point) (line-end-position))
              files))
      (append '("." ".." "../..") files)))
  "Paths to directories with header files."
  :type '(repeat string)
  :set-after '(clang-capf-clang))

(defcustom clang-capf-extra-flags nil
  "Additional flags to call clang with."
  :type '(repeat string))

(defcustom clang-capf-ignore-case nil
  "Should completion ignore case."
  :type 'boolean)

(defcustom clang-capf-show-type t
  "Should completion show types."
  :type 'boolean)

(defcustom clang-capf-add-parens t
  "Should completions automatically add parentheses."
  :type 'boolean)

(defcustom clang-capf-complete-empty nil
  "Should completion be attempted if nothing is at point."
  :type 'boolean)

(defun clang-capf--parse-signature (sig)
  "Parse the signature string SIG generated by clang."
  (save-match-data
    (when (string-match (rx bol (? "[#" (group (+ nonl)) "#]")
                            (+? (or word ?_))
                            (? "(" (group (* nonl)) ")")
                            eol)
                        sig)
      (format " %s(%s)"
              (or (match-string 1 sig) "")
              (if (match-beginning 2)
                   (replace-regexp-in-string
                    (rx (or "<#" "#>")) ""
                    (match-string 2 sig))
                "")))))

(defun clang-capf--parse-output ()
  "Return a list of completion candidates."
  (let (results)
    (while (search-forward-regexp
            (rx bol "COMPLETION: "
                (group (+ (or word ?_)))
                " : " (group (+ nonl)) eol)
            nil t)
      (push (propertize (match-string 1)
                        'clang-capf-signature
                        (clang-capf--parse-signature (match-string 2)))
            results))
    results))

(defun clang-capf--completions (&rest _ignore)
  "Call clang to collect suggestions at point."
  ;; NOTE: with-temp-buffer cannot be used, because the process must
  ;; be called in the actual code buffer, and `call-process-region'
  ;; interprets START and END relativly to the current buffer.
  (let* ((temp (generate-new-buffer " *clang*"))
         (args `(,(point-min) ,(point-max)
                 ,clang-capf-clang nil ,temp nil
                 "-cc1" "-fsyntax-only"
                 "-code-completion-macros"
                 ,@(mapcar (apply-partially #'concat "-I")
                           clang-capf-include-paths)
                 ,@clang-capf-extra-flags
                 ,(format "-code-completion-at=-:%d:%d"
                          (line-number-at-pos)
                          (1+ (length (encode-coding-region
                                       (line-beginning-position)
                                       (point) 'utf-8 t))))
                 "-")))
    (prog2 (apply #'call-process-region args)
        (with-current-buffer temp
          (goto-char (point-min))
          (clang-capf--parse-output))
      (kill-buffer temp))))

(defun clang-capf--annotate (str)
  "Extract type of completed symbol from STR as annotation."
  (get-text-property 0 'clang-capf-signature str))

(defun clang-capf--exit (str finished)
  "Add parentheses if applicable based on STR.
FINISHED contains the final state of the completion."
  (let ((sig (get-text-property 0 'clang-capf-signature str)))
    (when (and (memq finished '(sole finished)) sig)
      (cond ((string-match-p (rx bos (* (or word "_")) "(") sig)
             (insert "()"))
            ((string-match-p (rx bos (* (or word "_")) "[") sig)
             (insert "[]"))
            ((string-match-p (rx bos (* (or word "_")) "{") sig)
             (insert "{}")))
      (forward-char -1))))

;;;###autoload
(defun clang-capf ()
  "Function used for `completion-at-point-functions' using clang."
  (unless (executable-find clang-capf-clang)
    (error "Company either not installed or not in path"))
  (let ((beg (save-excursion
               (skip-syntax-backward "w_")
               (point)))
        (end (save-excursion
               (skip-syntax-forward "w_")
               (point))))
    (and (or (not clang-capf-complete-empty)
             (/= beg end)
             (not (looking-back (rx (or bol (+ space))) (point-min))))
         (list beg end
               (completion-table-with-cache #'clang-capf--completions
                                            clang-capf-ignore-case)
               :annotation-function (and clang-capf-show-type
                                         #'clang-capf--annotate)
               :exit-function #'clang-capf--exit
               :exclusive 'no))))

;;;###autoload
(define-obsolete-function-alias 'cpp-capf #'clang-capf "2020-05-26")

(provide 'clang-capf)

;;; clang-capf.el ends here
