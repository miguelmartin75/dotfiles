;;; diff-hl-integration-test.el --- Real diff-hl Git workflow test -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'diff-hl)

(unless (fboundp 'my/diff-hl-preview-revert-hunk)
  (load (expand-file-name "init.el"
                          (file-name-directory
                           (or load-file-name buffer-file-name)))
        nil nil nil t))

(defun my/diff-hl-integration-git (directory &rest arguments)
  "Run Git with ARGUMENTS in DIRECTORY and return its output."
  (let ((default-directory directory))
    (with-temp-buffer
      (unless (zerop (apply #'process-file "git" nil t nil arguments))
        (error "Git failed: %s" (buffer-string)))
      (buffer-string))))

(ert-deftest my/diff-hl-update-stage-revert-and-index-state ()
  (let* ((directory (file-name-as-directory
                     (make-temp-file "diff-hl-integration-" t)))
         (file (expand-file-name "sample.txt" directory))
         buffer)
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten\neleven\ntwelve\n"))
          (my/diff-hl-integration-git directory "init" "--quiet")
          (my/diff-hl-integration-git directory "config" "user.email" "test@example.com")
          (my/diff-hl-integration-git directory "config" "user.name" "Test User")
          (my/diff-hl-integration-git directory "add" "sample.txt")
          (my/diff-hl-integration-git directory "commit" "--quiet" "-m" "initial")
          (setq buffer (find-file-noselect file))
          (let ((diff-hl-update-async nil)
                (diff-hl-show-staged-changes nil)
                (diff-hl-highlight-reference-function nil)
                (diff-hl-ask-before-revert-hunk nil))
            (with-current-buffer buffer
              (erase-buffer)
              (insert "ONE\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten\neleven\nTWELVE\n")
              (save-buffer)
              (diff-hl-mode 1)
              (diff-hl-update)
              (let ((hunks (cl-remove-if-not
                            (lambda (overlay)
                              (overlay-get overlay 'diff-hl-hunk))
                            (overlays-in (point-min) (point-max)))))
                (should (= (length hunks) 2))
                (goto-char (overlay-start (car hunks))))
              (let ((source (buffer-string))
                    (working-diff
                     (my/diff-hl-integration-git
                      directory "diff" "--" "sample.txt"))
                    (index-diff
                     (my/diff-hl-integration-git
                      directory "diff" "--cached" "--" "sample.txt"))
                    (hunk-bounds
                     (mapcar
                      (lambda (overlay)
                        (cons (overlay-start overlay) (overlay-end overlay)))
                      (cl-remove-if-not
                       (lambda (overlay)
                         (overlay-get overlay 'diff-hl-hunk))
                       (overlays-in (point-min) (point-max)))))
                    prompts)
                (let ((diff-hl-ask-before-revert-hunk t))
                  (dolist (command '(diff-hl-revert-hunk
                                     my/diff-hl-preview-revert-hunk))
                    (cl-letf (((symbol-function 'yes-or-no-p)
                               (lambda (prompt)
                                 (push prompt prompts)
                                 nil)))
                      (should-error (funcall command) :type 'user-error))
                    (set-buffer buffer)
                    (should (equal (buffer-string) source))
                    (should (equal
                             (my/diff-hl-integration-git
                              directory "diff" "--" "sample.txt")
                             working-diff))
                    (should (equal
                             (my/diff-hl-integration-git
                              directory "diff" "--cached" "--" "sample.txt")
                             index-diff))
                    (should
                     (equal
                      (mapcar
                       (lambda (overlay)
                         (cons (overlay-start overlay) (overlay-end overlay)))
                       (cl-remove-if-not
                        (lambda (overlay)
                          (overlay-get overlay 'diff-hl-hunk))
                        (overlays-in (point-min) (point-max))))
                      hunk-bounds))))
                (should (= (length prompts) 2)))
              (diff-hl-stage-current-hunk)
              (should (string-match-p "ONE"
                                      (my/diff-hl-integration-git
                                       directory "diff" "--cached" "--" "sample.txt")))
              (should (string-match-p "TWELVE"
                                      (my/diff-hl-integration-git
                                       directory "diff" "--" "sample.txt")))
              (accept-process-output nil 0.1)
              (diff-hl-update)
              (accept-process-output nil 0.1)
              (let ((hunks (cl-remove-if-not
                            (lambda (overlay)
                              (overlay-get overlay 'diff-hl-hunk))
                            (overlays-in (point-min) (point-max)))))
                (should (= (length hunks) 1))
                (goto-char (overlay-start (car hunks))))
              (diff-hl-revert-hunk)
              (should (equal (buffer-string)
                             "ONE\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine\nten\neleven\ntwelve\n"))
              (should (string-empty-p
                       (my/diff-hl-integration-git directory "diff" "--" "sample.txt")))
              (should (string-match-p "ONE"
                                      (my/diff-hl-integration-git
                                       directory "diff" "--cached" "--" "sample.txt")))
              (diff-hl-mode -1))))
      (when (buffer-live-p buffer)
        (kill-buffer buffer))
      (when (file-directory-p directory)
        (delete-directory directory t)))))

;;; diff-hl-integration-test.el ends here
