;;; my-workspace-state.el --- Restartable workspace configurations -*- lexical-binding: t; -*-

;;; Commentary:

;; Persist only the identifiers and descriptors needed to reconstruct managed
;; workspace tabs.  Buffers, processes, windows, and runtime caches stay local
;; to one Emacs process.

;;; Code:

(require 'subr-x)
(require 'tab-bar)
(require 'my-workflow)

(declare-function my/layout-entry "my-window-layouts" (layout))
(declare-function my/layout-target-matches-root-p "my-window-layouts"
                  (target root))
(declare-function my/workspace-configuration-select "my-window-layouts"
                  (&optional id state))

(defgroup my/workspace-state nil
  "Restartable named workspace configurations."
  :group 'convenience)

(defcustom my/workspace-state-file
  (expand-file-name "workspace-state.el" user-emacs-directory)
  "File containing reconstructable managed workspace state."
  :type 'file)

(defcustom my/workspace-state-restore-on-initialize t
  "Whether `my/workspace-state-initialize' restores saved workspaces."
  :type 'boolean)

(defvar my/workspace-state-initialized nil
  "Non-nil after workspace state hooks and optional restore are initialized.")

(defun my/workspace-state-zmx-descriptor (target)
  "Return TARGET's reconstructable zmx descriptor, or nil."
  (when (and (listp target)
             (eq (plist-get target :type) 'zmx)
             (stringp (plist-get target :name))
             (not (string-empty-p (plist-get target :name)))
             (stringp (plist-get target :directory))
             (stringp (plist-get target :cwd)))
    (list :type 'zmx
          :name (plist-get target :name)
          :directory (plist-get target :directory)
          :cwd (plist-get target :cwd))))

(defun my/workspace-state-tab-record (tab)
  "Return TAB's reconstructable workspace record, or nil."
  (let* ((properties (cdr tab))
         (id (alist-get 'my/workspace-id properties))
         (root (alist-get 'my/workspace-root properties))
         (layout (alist-get 'my/layout-current properties))
         (edit (alist-get 'my/layout-edit-buffer properties))
         (edit-file (and (buffer-live-p edit) (buffer-file-name edit)))
         (terminal-target
          (my/workspace-state-zmx-descriptor
           (alist-get 'my/layout-terminal-target properties)))
         (agent-target
          (my/workspace-state-zmx-descriptor
           (alist-get 'my/layout-agent-target properties))))
    (when (and (stringp id) (stringp root) (symbolp layout))
      (append (list :id id
                    :layout layout
                    :task-id (alist-get 'my/work-task-id properties)
                    :edit-file edit-file)
              (when terminal-target (list :terminal-target terminal-target))
              (when agent-target (list :agent-target agent-target))))))

(defun my/workspace-state-save ()
  "Save ordered reconstructable workspace configuration state."
  (interactive)
  (let ((selected-id (my/tab-current-property 'my/workspace-id))
        records)
    (dolist (tab (tab-bar-tabs))
      (let ((record (my/workspace-state-tab-record tab)))
        (when record
          (push record records))))
    (make-directory (file-name-directory my/workspace-state-file) t)
    (with-temp-file my/workspace-state-file
      (let ((print-length nil)
            (print-level nil))
        (prin1 (list :version 1
                     :selected-id selected-id
                     :workspaces (nreverse records))
               (current-buffer))
        (insert "\n")))
    (when (called-interactively-p 'interactive)
      (message "Saved %d workspace configuration%s"
               (length records) (if (= (length records) 1) "" "s")))))

(defun my/workspace-state-read ()
  "Read and validate the top-level workspace state file."
  (unless (file-regular-p my/workspace-state-file)
    (user-error "Workspace state file does not exist: %s"
                my/workspace-state-file))
  (let (state)
    (with-temp-buffer
      (insert-file-contents my/workspace-state-file)
      (setq state (read (current-buffer))))
    (unless (and (listp state)
                 (equal (plist-get state :version) 1)
                 (listp (plist-get state :workspaces)))
      (user-error "Workspace state file has an unsupported format"))
    state))

(defun my/workspace-state-validate-record (record)
  "Return RECORD after validating its reconstructable fields."
  (unless (listp record)
    (user-error "Workspace state record is not a plist"))
  (let* ((id (plist-get record :id))
         (layout (plist-get record :layout))
         (task-id (plist-get record :task-id))
         (edit-file (plist-get record :edit-file))
         (configuration (my/workspace-configuration id))
         (root (plist-get configuration :root)))
    (unless (file-directory-p root)
      (user-error "Workspace root does not exist: %s" root))
    (my/layout-entry layout)
    (when (and task-id (not (stringp task-id)))
      (user-error "Workspace task ID must be a string"))
    (when (and edit-file (not (stringp edit-file)))
      (user-error "Workspace edit file must be a file name"))
    (dolist (property '(:terminal-target :agent-target))
      (when (plist-member record property)
        (let ((target
               (my/workspace-state-zmx-descriptor (plist-get record property))))
          (unless target
            (user-error "Workspace %s has an invalid zmx descriptor" id))
          (unless (my/layout-target-matches-root-p target root)
            (user-error "Workspace %s has a zmx descriptor for another root" id)))))
    record))

(defun my/workspace-state-restore ()
  "Restore saved workspace configurations independently and summarize failures."
  (interactive)
  (let* ((state (my/workspace-state-read))
         (records (plist-get state :workspaces))
         (selected-id (plist-get state :selected-id))
         (initial-unmanaged
          (and (= (length (tab-bar-tabs)) 1)
               (null (my/tab-current-property 'my/workspace-id))))
         restored
         failures)
    (dolist (record records)
      (condition-case error-data
          (let* ((record (my/workspace-state-validate-record record))
                 (id (plist-get record :id)))
            (my/workspace-configuration-select id record)
            (push id restored))
        (error
         (push (format "%s: %s"
                       (or (and (listp record) (plist-get record :id))
                           "invalid record")
                       (error-message-string error-data))
               failures))))
    (setq restored (nreverse restored)
          failures (nreverse failures))
    (when (and initial-unmanaged restored)
      (tab-bar-select-tab 1)
      (tab-bar-close-tab))
    (when (and (stringp selected-id) (member selected-id restored))
      (tab-bar-select-tab (my/workspace-tab-index-by-id selected-id)))
    (if failures
        (message "Restored %d workspace configuration%s; %d failed: %s"
                 (length restored) (if (= (length restored) 1) "" "s")
                 (length failures) (string-join failures "; "))
      (message "Restored %d workspace configuration%s"
               (length restored) (if (= (length restored) 1) "" "s")))
    (list :restored restored :failures failures)))

(defun my/workspace-state-save-on-exit ()
  "Save workspace state during shutdown without aborting Emacs exit."
  (condition-case error-data
      (my/workspace-state-save)
    (error
     (message "Could not save workspace state: %s"
              (error-message-string error-data)))))

(defun my/workspace-state-initialize ()
  "Initialize workspace persistence after workflow and layout modules load."
  (interactive)
  (unless my/workspace-state-initialized
    (add-hook 'kill-emacs-hook #'my/workspace-state-save-on-exit)
    (setq my/workspace-state-initialized t)
    (when (and my/workspace-state-restore-on-initialize
               (file-regular-p my/workspace-state-file))
      (condition-case error-data
          (my/workspace-state-restore)
        (error
         (remove-hook 'kill-emacs-hook #'my/workspace-state-save-on-exit)
         (message "Could not restore workspace state: %s"
                  (error-message-string error-data)))))))

(provide 'my-workspace-state)

;;; my-workspace-state.el ends here
