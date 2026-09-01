;;; my-org-datetree-test.el --- Datetree command behavior tests -*- lexical-binding: t; -*-

(require 'ert)

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'my-org-datetree)

(ert-deftest my/org-datetree-copy-and-refile-to-file ()
  (let ((destination (make-temp-file "my-org-datetree-" nil ".org"))
        (copy-source (generate-new-buffer " *datetree-copy-source*"))
        (refile-source (generate-new-buffer " *datetree-refile-source*")))
    (unwind-protect
        (progn
          (with-current-buffer copy-source
            (org-mode)
            (insert "* Copy source\n:PROPERTIES:\n:TIMESTAMP: [2024-02-03 Sat]\n:END:\nCopy body\n")
            (goto-char (point-min))
            (my/org-copy-to-datetree destination)
            (should (string-match-p "Copy source" (buffer-string))))
          (with-current-buffer refile-source
            (org-mode)
            (insert "* Refile source\n:PROPERTIES:\n:TIMESTAMP: [2024-02-03 Sat]\n:END:\nRefile body\n")
            (goto-char (point-min))
            (my/org-refile-to-datetree destination)
            (should-not (string-match-p "Refile source" (buffer-string))))
          (with-current-buffer (get-file-buffer destination)
            (should (string-match-p "2024" (buffer-string)))
            (should (string-match-p "Copy source" (buffer-string)))
            (should (string-match-p "Refile source" (buffer-string)))))
      (dolist (buffer (list copy-source refile-source
                            (get-file-buffer destination)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))
      (delete-file destination))))

;;; my-org-datetree-test.el ends here
