;;; maven.el --- helpers for compiling with maven

;; Copyright (C) 2013 Andrew Gwozdziewycz

;; Version: 0.1
;; Author: Andrew Gwozdziewycz <git@apgwoz.com>
;; Created: Oct 2013
;; Version: 0.3.0
;; Keywords: languages, tools, compilation, maven
;; URL: https://github.com/apgwoz/moka-mode

;; This is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 3, or (at your option) any later
;; version.

;; This is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;; This file is NOT part of GNU emacs. It is however part of moka-mode

;;; Commentary:

;; This file is in flux, and is sparsely documented. Please excuse.


(defcustom moka-mvn-build-file-name "pom.xml"
  "Name of the mvn project file. This is usually `pom.xml`,
however it is possible to invoke maven with an alternative
filename.  TODO: always invoke mvn with the -f flag to specify
the pom.xml (or if it's customized, that file)
"
  :type 'string
  :group 'moka)

(defcustom moka-mvn-command "mvn"
  "Name of maven command. This can be a fully qualified path
should the executable be installed somewhere that isn't on
the path"
  :type 'string
  :group 'moka)

(defvar moka-mvn-last-task "compile")
(defvar moka-mvn-last-test "")
(defvar moka-mvn-tasks-default '("compile" "test" "clean" "install" "package"))

(defun moka-mvn-get-task (directory)
  (let ((task (completing-read-multiple "Goal (default): "
                                        moka-mvn-tasks-default)))
    (if (> (length task) 0)
        (mapconcat 'identity task " ")
      "")))

(defun moka-mvn-find-root (&optional indicator directory)
  (let ((cwd (or directory default-directory))
        (indicator (or indicator moka-mvn-build-file-name)))
    (message (concat "cwd: " cwd " indicator: " indicator))
    (locate-dominating-file cwd indicator)))

(defun moka-mvn-kill-cache ()
  (interactive)
  (setq *moka-mvn-tasks-cache* '()))

(defun moka-mvn (&optional task args)
  "Run mvn `task` in project root directory."
  (interactive)
  (let ((default-directory (moka-mvn-find-root moka-mvn-build-file-name)))
    (if default-directory
        (let ((task (or task (moka-mvn-get-task default-directory))))
          (setq moka-mvn-last-task task)
          (compile (concat moka-mvn-command " " task " " args)))
      (message "Couldn't find a maven project."))))

(defun moka-mvn-last ()
  "Run the last maven task in project"
  (interactive)
  (moka-mvn (or moka-mvn-last-task "")))

(defun moka-mvn-compile ()
  (interactive)
  (moka-mvn "compile"))

(defun moka-mvn-clean ()
  (interactive)
  (moka-mvn "clean"))

(defun moka-mvn-test (&optional prefix)
  (interactive
   (if (null current-prefix-arg)
       (list "")
     (list (read-string "Test: " moka-mvn-last-test nil ""))))
  (if (> (length prefix) 0)
      (progn
        (setq moka-mvn-last-test prefix)
        (moka-mvn "test" (concat "-Dtest=" prefix)))
    (moka-mvn "test")))

(defun moka-mvn-test-this (&optional prefix)
  "With a prefix argument, tests the current method in the current file"
  (interactive "p")
  (let ((package (moka-current-package-name))
        (class (moka-current-class-name))
        (method (and prefix (moka-current-method-name))))
    (if package
        (let ((testname (concat package "." class (when method (concat "#" method)))))
          (setq moka-mvn-last-test testname)
          (moka-mvn "test" (concat "-Dtest=" testname)))
      (moka-mvn-test t))))

;; temporary. All of this stuff should change directory to the directory before running
(defun moka-mvn-classpath ()
  "Determines the classpath used by mvn for a project"
  (let ((default-directory (moka-mvn-find-root moka-mvn-build-file-name)))
    (if default-directory
        (let* ((output (shell-command-to-string
                        (concat moka-mvn-command " dependency:build-classpath")))
               (lines (moka-filter-list
                       (split-string output "\n")
                       (lambda (x) (not
                                    (or (string-equal x "")
                                        (not (string-equal (substring x 0 1) "/") )))))))
          (if (null lines)
              nil
            (split-string (car lines) ":")))
      (message "Couldn't find a maven project."))))

(provide 'moka-mvn)
