;;; my-org-datetree.el --- Copy and refile Org subtrees by date -*- lexical-binding: t; -*-

;;; Commentary:

;; Commands for placing the current Org subtree in a datetree selected by its
;; TIMESTAMP property or the current date.

;;; Code:

(require 'org)
(require 'org-datetree)

(defun my/org-copy-to-datetree (&optional file)
  "Copy a subtree to the datetree selected by its timestamp.

The current time is used if the entry has no timestamp. If FILE
is nil, copy in the current file."
  (interactive "f")
  (let* ((datetree-date (or (org-entry-get nil "TIMESTAMP" t)
                            (org-read-date t nil "now")))
         (date (org-date-to-gregorian datetree-date)))
    (save-excursion
      (org-copy-subtree)
      (when file
        (find-file file))
      (org-datetree-find-date-create date)
      (org-narrow-to-subtree)
      (outline-show-subtree)
      (org-end-of-subtree t)
      (newline)
      (goto-char (point-max))
      (org-paste-subtree 4)
      (widen))))

(defun my/org-refile-to-datetree (&optional file)
  "Refile a subtree to the datetree selected by its timestamp.

The current time is used if the entry has no timestamp. If FILE
is nil, refile in the current file."
  (interactive "f")
  (let* ((datetree-date (or (org-entry-get nil "TIMESTAMP" t)
                            (org-read-date t nil "now")))
         (date (org-date-to-gregorian datetree-date)))
    (save-excursion
      (org-cut-subtree)
      (when file
        (find-file file))
      (org-datetree-find-date-create date)
      (org-narrow-to-subtree)
      (outline-show-subtree)
      (org-end-of-subtree t)
      (newline)
      (goto-char (point-max))
      (org-paste-subtree 4)
      (widen))))

(provide 'my-org-datetree)

;;; my-org-datetree.el ends here
