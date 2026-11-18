;;; my-workflow.el --- Project-partitioned Org work items -*- lexical-binding: t; -*-

;;; Commentary:

;; Local Org tasks, project indexes, daily work logging, and their small tab
;; projection.  This module intentionally has no tracker, agent, network, or
;; terminal dependency.

;;; Code:

(require 'calendar)
(require 'dired)
(require 'org)
(require 'org-datetree)
(require 'org-element)
(require 'org-id)
(require 'project)
(require 'seq)
(require 'subr-x)
(require 'tab-bar)

(defgroup my/workflow nil
  "Project-partitioned local Org work items."
  :group 'org)

(defcustom my/work-shared-directory
  (expand-file-name "~/morg/shared/")
  "Shared personal Org and Markdown store."
  :type 'directory)

(defcustom my/work-private-directory
  (expand-file-name "~/morg/private/")
  "Private Org and Markdown store."
  :type 'directory)

(defcustom my/workflow-project-storage-root
  (expand-file-name "projects/" my/work-shared-directory)
  "Directory containing one canonical index for each shared project."
  :type 'directory)

(defcustom my/workflow-private-project-storage-root
  (expand-file-name "projects/" my/work-private-directory)
  "Directory containing one canonical index for each private project."
  :type 'directory)

(defcustom my/workflow-life-file
  (expand-file-name "notes/irl/life.org" my/work-shared-directory)
  "Optional non-work Org file included in the agenda when it exists."
  :type 'file)

(defun my/work-store-directory (store)
  "Return STORE's note directory, accepting only shared or private."
  (pcase store
    ("shared" my/work-shared-directory)
    ("private" my/work-private-directory)
    (_ (user-error "Unknown note store: %s" store))))

(defun my/workflow-project-storage-directory (store)
  "Return STORE's project directory."
  (pcase store
    ("shared" my/workflow-project-storage-root)
    ("private" my/workflow-private-project-storage-root)
    (_ (user-error "Unknown project store: %s" store))))

(defun my/work-store-read ()
  "Choose the store for an explicit cross-store command."
  (completing-read "Store: " '("shared" "private") nil t nil nil "shared"))

(defun my/work-store-for-file (file)
  "Return the store owning FILE, or nil for a file outside both stores."
  (when file
    (seq-find
     (lambda (store)
       (seq-some
        (lambda (directory)
          (or (string-prefix-p (file-name-as-directory (expand-file-name directory))
                               (expand-file-name file))
              (and (file-directory-p directory)
                   (file-in-directory-p file directory))))
        (list (my/work-store-directory store)
              (my/workflow-project-storage-directory store))))
     '("shared" "private"))))

(defun my/workflow-current-store ()
  "Return the file or tab task's store, giving private context precedence."
  (let* ((file-store (my/work-store-for-file (buffer-file-name)))
         (task-id (my/tab-current-property 'my/work-task-id))
         (task-store (when task-id
                       (plist-get (my/workflow-find-task task-id) :store))))
    (if (or (equal file-store "private") (equal task-store "private"))
        "private"
      (or file-store task-store "shared"))))

(defun my/workflow-journal-file (&optional store time)
  "Return STORE's annual journal for TIME, defaulting to the current context."
  (expand-file-name
   (format-time-string "logs/%Y/journal.org" time)
   (my/work-store-directory (or store (my/workflow-current-store)))))

(defun my/workflow-journal-capture-file ()
  "Return the context's annual journal, creating its parent directory."
  (let ((file (my/workflow-journal-file)))
    (make-directory (file-name-directory file) t)
    file))

(defun my/workflow-reflections-capture-file ()
  "Return the context's annual reflections file, creating its directory."
  (let ((file (expand-file-name
               (format-time-string "logs/%Y/reflections.org")
               (my/work-store-directory (my/workflow-current-store)))))
    (make-directory (file-name-directory file) t)
    file))

(defun my/workflow-life-capture-file ()
  "Return the life capture file, creating its required headings when absent.

Existing files are preserved.  Unsaved visiting buffers and creation failures
stop capture before an existing destination can be overwritten."
  (unless (file-exists-p my/workflow-life-file)
    (let ((buffer (get-file-buffer my/workflow-life-file)))
      (when (and buffer (buffer-modified-p buffer))
        (user-error "Life capture file has unsaved contents"))
      (make-directory (file-name-directory my/workflow-life-file) t)
      (with-temp-buffer
        (insert "* Backlog\n** Inbox\n\n"
                "* Areas\n** Ideas\n** Writing Ideas\n"
                "** Startup Ideas\n** Research Ideas\n")
        (write-region (point-min) (point-max) my/workflow-life-file
                      nil 'silent nil 'excl))
      (when buffer
        (with-current-buffer buffer
          (revert-buffer t t)))
      (my/workflow-refresh-agenda)))
  my/workflow-life-file)

(defcustom my/workspace-configurations nil
  "Named workspace configurations keyed by stable string IDs.

Each entry has the form (ID :name NAME :root ROOT :entry ENTRY :layout LAYOUT).
NAME and ROOT are required.  ENTRY is an optional file, absolute or relative to
ROOT.  LAYOUT is an optional layout symbol that defaults to `focus'.  IDs
beginning with
\"directory:\" are reserved for deterministic directory workspaces."
  :type 'sexp)

(defconst my/workflow-log-kinds
  '(start progress decision blocker handoff done)
  "Supported explicit labels for global work-log entries.")

(defun my/workflow-validate-one-line (text description)
  "Return TEXT trimmed when it is a nonempty single line for DESCRIPTION."
  (unless (and (stringp text)
               (not (string-empty-p (string-trim text)))
               (not (string-match-p "[\r\n]" text)))
    (user-error "%s must be one nonempty line" description))
  (string-trim text))

(defun my/workspace-normalize-root (directory)
  "Return DIRECTORY's project or directory root with one trailing slash.

Project discovery is nonprompting, preserves TRAMP prefixes, and never resolves
symlinks with `file-truename'."
  (let* ((directory (file-name-as-directory (expand-file-name directory)))
         (project (project-current nil directory))
         (root (if project (project-root project) directory)))
    (file-name-as-directory (expand-file-name root))))

(defun my/workspace-canonical-directory (directory)
  "Return exact DIRECTORY as an absolute name with one trailing slash."
  (file-name-as-directory (expand-file-name directory)))

(defun my/workspace-default-id (root)
  "Return the deterministic workspace ID for exact canonical ROOT."
  (concat "directory:" (my/workspace-canonical-directory root)))

(defun my/workspace-configuration (id)
  "Return the validated workspace configuration for stable string ID."
  (unless (and (stringp id) (not (string-empty-p id)))
    (user-error "Workspace configuration ID must be a nonempty string"))
  (let ((entry (assoc id my/workspace-configurations))
        configuration)
    (if entry
        (let ((name (plist-get (cdr entry) :name))
              (root (plist-get (cdr entry) :root))
              (edit-entry (plist-get (cdr entry) :entry))
              (layout (plist-get (cdr entry) :layout)))
          (unless (and (stringp name) (not (string-empty-p name)))
            (user-error "Workspace configuration %s needs a nonempty :name" id))
          (unless (and (stringp root) (not (string-empty-p root)))
            (user-error "Workspace configuration %s needs a nonempty :root" id))
          (when (and edit-entry (not (stringp edit-entry)))
            (user-error "Workspace configuration %s :entry must be a file name" id))
          (when (and layout (not (symbolp layout)))
            (user-error "Workspace configuration %s :layout must be a symbol" id))
          (setq configuration
                (list :id id :name name
                      :root (my/workspace-canonical-directory root)
                      :entry edit-entry :layout (or layout 'focus))))
      (unless (string-prefix-p "directory:" id)
        (user-error "Unknown workspace configuration %s" id))
      (let ((root (substring id (length "directory:"))))
        (unless (and (file-name-absolute-p root)
                     (equal id (my/workspace-default-id root)))
          (user-error "Invalid deterministic workspace configuration ID"))
        (setq configuration
              (list :id id
                    :name (or (file-name-nondirectory (directory-file-name root))
                              root)
                    :root root :layout 'focus))))
    configuration))

(defun my/tab-current-property (property)
  "Return PROPERTY from the current tab's public property alist."
  (let (result)
    (dolist (tab (tab-bar-tabs))
      (when (eq (car tab) 'current-tab)
        (setq result (alist-get property (cdr tab)))))
    result))

(defun my/tab-set-current-property (property value)
  "Set current tab PROPERTY to VALUE, removing it when VALUE is nil."
  (let (tabs)
    (dolist (tab (tab-bar-tabs))
      (if (eq (car tab) 'current-tab)
          (let ((properties (assq-delete-all property (copy-sequence (cdr tab)))))
            (when value
              (push (cons property value) properties))
            (push (cons 'current-tab properties) tabs))
        (push tab tabs)))
    (tab-bar-tabs-set (nreverse tabs))
    value))

(defun my/tab-find-index-by-property (property value)
  "Return the one-based public tab index whose PROPERTY is exactly VALUE."
  (let ((index 0)
        result)
    (dolist (tab (tab-bar-tabs))
      (setq index (1+ index))
      (when (and (null result)
                 (equal (alist-get property (cdr tab)) value))
        (setq result index)))
    result))

(defun my/workspace-tab-index-by-id (id)
  "Return the tab index managed for workspace configuration ID, or nil."
  (my/tab-find-index-by-property
   'my/workspace-id id))

(defun my/workspace-tab-indices-for-root (root)
  "Return every tab index whose exact workspace root is normalized ROOT."
  (let ((root (my/workspace-canonical-directory root))
        (index 0)
        result)
    (dolist (tab (tab-bar-tabs))
      (setq index (1+ index))
      (when (equal (alist-get 'my/workspace-root (cdr tab)) root)
        (push index result)))
    (nreverse result)))

(defun my/workspace-task-tab-index (root task-id)
  "Return ROOT's unique tab bound to TASK-ID, or nil.

Signal an error when duplicate tab bindings make the result ambiguous."
  (let (matches)
    (dolist (index (my/workspace-tab-indices-for-root root))
      (let ((tab (nth (1- index) (tab-bar-tabs))))
        (when (equal (alist-get 'my/work-task-id (cdr tab)) task-id)
          (push index matches))))
    (when (> (length matches) 1)
      (user-error "Task %s is bound to multiple workspace tabs" task-id))
    (car matches)))

(defun my/workspace-tab-index (root)
  "Return the deterministic directory workspace tab for ROOT, or nil.

An existing unique root-only tab is returned so the running Emacs session can
adopt the stable ID when this configuration is reloaded."
  (or (my/workspace-tab-index-by-id (my/workspace-default-id root))
      (let (matches)
        (dolist (index (my/workspace-tab-indices-for-root root))
          (let ((tab (nth (1- index) (tab-bar-tabs))))
            (unless (alist-get 'my/workspace-id (cdr tab))
              (push index matches))))
        (when (= (length matches) 1)
          (car matches)))))

(defun my/workspace-select-or-create-tab (root &optional id name)
  "Select ROOT's managed tab by ID, creating it when absent.

ID defaults to ROOT's deterministic directory-workspace ID.  Tab names are
display labels only and never workspace identity."
  (let* ((root (if id
                   (my/workspace-canonical-directory root)
                 (my/workspace-normalize-root root)))
         (id (or id (my/workspace-default-id root)))
         (index (my/workspace-tab-index-by-id id)))
    (if index
        (progn
          (tab-bar-select-tab index)
          (unless (equal (my/tab-current-property 'my/workspace-root) root)
            (user-error "Workspace configuration %s is already bound to another root" id)))
      (tab-bar-new-tab)
      (my/tab-set-current-property 'my/workspace-id id)
      (my/tab-set-current-property 'my/workspace-root root)
      (my/tab-set-current-property 'my/layout-current 'focus)
      (tab-bar-rename-tab
       (or name (file-name-nondirectory (directory-file-name root)))))
    root))

(defun my/workflow-validate-project-key (project-key)
  "Return PROJECT-KEY when it is a safe single path component.

Signal `user-error' before composing any project storage path otherwise."
  (let ((project-key (my/workflow-validate-one-line project-key "Project key")))
    (unless (and
               (not (file-name-absolute-p project-key))
               (not (string-prefix-p "~" project-key))
               (not (member project-key '("." "..")))
               (not (string-match-p "[\\\\/]" project-key)))
      (user-error "Project key must be one nonempty directory component"))
    project-key))

(defun my/workflow-project-index-file (project-key &optional store)
  "Return PROJECT-KEY's canonical index in STORE, which defaults to shared."
  (let ((project-key (my/workflow-validate-project-key project-key)))
    (when (and (equal store "private") (equal project-key "imported"))
      (user-error "The imported directory is reserved for legacy private notes"))
    (expand-file-name
     "index.org"
     (expand-file-name
      (file-name-as-directory project-key)
      (my/workflow-project-storage-directory (or store "shared"))))))

(defun my/workflow-heading-children (position)
  "Return direct headline children below POSITION as (TITLE . POSITION) pairs."
  (save-excursion
    (goto-char position)
    (org-back-to-heading t)
    (let ((level (org-outline-level))
          (end (save-excursion (org-end-of-subtree t)))
          result)
      (forward-line 1)
      (when (< (point) end)
        (while (re-search-forward org-heading-regexp end t)
          (when (= (org-outline-level) (1+ level))
            (push (cons (org-get-heading t t t t) (line-beginning-position)) result))))
      (nreverse result))))

(defun my/workflow-project-schema (buffer)
  "Return BUFFER's validated canonical project schema, or nil.

The result provides heading positions for the project, active tasks, archive,
and project log."
  (with-current-buffer buffer
    (org-with-wide-buffer
     (save-excursion
       (goto-char (point-min))
       (let (projects)
         (while (re-search-forward org-heading-regexp nil t)
           (when (= (org-outline-level) 1)
             (push (line-beginning-position) projects)))
         (when (= (length projects) 1)
           (let* ((project-position (car projects))
                  (branches (my/workflow-heading-children project-position))
                  (docs (seq-filter (lambda (branch) (equal (car branch) "Docs"))
                                    branches))
                  (tasks (seq-filter (lambda (branch) (equal (car branch) "Tasks"))
                                     branches))
                  (log (seq-filter (lambda (branch) (equal (car branch) "Log"))
                                   branches)))
             (when (and (= (length docs) 1)
                        (= (length tasks) 1)
                        (= (length log) 1)
                        (< (cdr (car docs)) (cdr (car tasks)) (cdr (car log))))
               (goto-char project-position)
               (let ((project-id (org-entry-get nil "ID"))
                     (project-key (org-entry-get nil "PROJECT_KEY"))
                     (project-root (org-entry-get nil "PROJECT_ROOT")))
                 (let* ((tasks (car tasks))
                        (docs (car docs))
                        (log (car log))
                        (task-branches (my/workflow-heading-children (cdr tasks)))
                        (active (seq-filter (lambda (branch) (equal (car branch) "Active"))
                                            task-branches))
                        (archive (seq-filter (lambda (branch) (equal (car branch) "Archive"))
                                             task-branches)))
                   (when (and (= (length active) 1)
                              (= (length archive) 1)
                              (< (cdr (car active)) (cdr (car archive))))
                     (let ((active (car active))
                           (archive (car archive)))
                       (goto-char (cdr archive))
                       (when (and
                              (member "ARCHIVE" (org-get-tags nil t))
                              project-id project-key project-root)
                         (list :buffer buffer
                               :store (my/work-store-for-file (buffer-file-name))
                               :project project-position
                               :docs (cdr docs)
                               :tasks (cdr tasks)
                               :active (cdr active)
                               :archive (cdr archive)
                               :log (cdr log)
                               :id project-id
                               :key project-key
                               :root project-root))))))))))))))

(defun my/workflow-discover-project-indexes (&optional store)
  "Return schema-valid indexes in STORE, or both stores when omitted."
  (let (result)
    (dolist (store (if store (list store) '("shared" "private")))
      (let ((root (my/workflow-project-storage-directory store)))
        (when (file-directory-p root)
          (dolist (entry (directory-files root t directory-files-no-dot-files-regexp))
            (when (file-directory-p entry)
              (let* ((project-key (file-name-nondirectory (directory-file-name entry)))
                     (index (expand-file-name "index.org" entry)))
                (when (file-regular-p index)
                  (let ((schema (my/workflow-project-schema (find-file-noselect index))))
                    (when (and schema (equal (plist-get schema :key) project-key))
                      (push index result))))))))))
    (sort result #'string-lessp)))

(defun my/workflow-project-choices (&optional store)
  "Return store-qualified existing project directory names in STORE or both."
  (let (choices)
    (dolist (store (if store (list store) '("shared" "private")))
      (let ((root (my/workflow-project-storage-directory store)))
        (when (file-directory-p root)
          (dolist (directory (directory-files root t directory-files-no-dot-files-regexp))
            (when (and (file-directory-p directory)
                       (not (and (equal store "private")
                                 (equal (file-name-nondirectory directory) "imported"))))
              (push (concat store "/" (file-name-nondirectory directory)) choices))))))
    (sort choices #'string-lessp)))

(defun my/workflow-refresh-agenda ()
  "Set `org-agenda-files' from existing life and canonical project indexes."
  (setq org-agenda-files
        (append (when (file-exists-p my/workflow-life-file)
                  (list my/workflow-life-file))
                (my/workflow-discover-project-indexes))))

(defun my/workflow-register-agenda-index (index)
  "Make existing canonical INDEX available to this Emacs agenda session."
  (when (file-exists-p index)
    (add-to-list 'org-agenda-files index)))

(defun my/workflow-project-key-for-root (root)
  "Derive an editable initial project key from normalized ROOT."
  (let* ((project (project-current nil root))
         (name (and project (project-name project)))
         (fallback (file-name-nondirectory (directory-file-name root))))
    (or name fallback "project")))

(defun my/workflow-read-project-key (root &optional store)
  "Read a project key for ROOT from safe existing choices or a new key."
  (let* ((default (my/workflow-project-key-for-root root))
         (choices (mapcar (lambda (choice) (substring choice (1+ (length (or store "shared")))))
                          (my/workflow-project-choices (or store "shared"))))
         (project-key (completing-read "Project key: " choices nil nil default)))
    (my/workflow-validate-project-key project-key)))

(defun my/workflow-read-project-selection (&optional root store existing-only)
  "Return a (STORE . KEY) selection, optionally requiring an existing project."
  (let* ((default (when root
                    (concat (or store (my/workflow-current-store)) "/"
                            (my/workflow-project-key-for-root root))))
         (choice (completing-read "Project (store/key): "
                                  (my/workflow-project-choices store) nil existing-only
                                  default)))
    (unless (string-match "\\`\\(shared\\|private\\)/\\(.+\\)\\'" choice)
      (user-error "Select a project as shared/key or private/key"))
    (cons (match-string 1 choice)
          (my/workflow-validate-project-key (match-string 2 choice)))))

(defun my/workflow-prepare-project (project-key root &optional confirm-reuse store)
  "Validate PROJECT-KEY and ROOT without creating a project.

Return an existing schema, or nil when the canonical project does not yet
exist.  Existing collisions and declined reuse fail before any mutation."
  (let* ((project-key (my/workflow-validate-project-key project-key))
         (root (my/workspace-canonical-directory root))
         (index (my/workflow-project-index-file project-key store))
         (directory (file-name-directory index))
         schema)
    (cond
     ((or (file-exists-p index) (file-symlink-p index))
      (unless (file-regular-p index)
        (user-error "Project index collision for %s" project-key))
      (setq schema (my/workflow-project-schema (find-file-noselect index)))
      (unless (and schema
                   (equal (plist-get schema :key) project-key)
                   (file-name-absolute-p (plist-get schema :root))
                   (not (string-match-p "[\r\n]" (plist-get schema :root))))
        (user-error "Project index collision for %s" project-key))
      (when (and confirm-reuse
                 (not (equal (plist-get schema :root) root))
                 (not (y-or-n-p
                       (format "Reuse project %s for %s? " project-key root))))
        (user-error "Choose a different project key")))
     ((and (or (file-exists-p directory) (file-symlink-p directory))
           (not (file-directory-p directory)))
      (user-error "Project directory collision for %s" project-key))
     ((let ((buffer (get-file-buffer index)))
        (and buffer (buffer-modified-p buffer)))
      (user-error "Project index has unsaved contents for %s" project-key)))
    schema))

(defun my/workflow-ensure-project (project-key root &optional confirm-reuse store)
  "Return PROJECT-KEY's canonical schema, creating it for ROOT when needed.

Existing ordinary project files are preserved when adding a missing index.
Malformed indexes and non-directory destinations are never overwritten.
When CONFIRM-REUSE is non-nil, a project first recorded at another root needs
explicit confirmation before reuse."
  (let* ((project-key (my/workflow-validate-project-key project-key))
         (root (my/workspace-canonical-directory root))
         (index (my/workflow-project-index-file project-key store))
         (directory (file-name-directory index))
         (schema (my/workflow-prepare-project project-key root confirm-reuse store)))
    (unless schema
      (make-directory directory t)
      (let ((buffer (find-file-noselect index)))
        (with-current-buffer buffer
          (erase-buffer)
          (org-mode)
          (insert "#+title: " project-key "\n"
                  "#+filetags: :work:project:\n\n"
                  "* " project-key "\n")
          (org-back-to-heading t)
          (org-id-get-create)
          (org-entry-put nil "PROJECT_KEY" project-key)
          (org-entry-put nil "PROJECT_ROOT" root)
          (goto-char (point-max))
          (insert "\n** Docs\n\n"
                  "** Tasks\n"
                  "*** Active\n\n"
                  "*** Archive :ARCHIVE:\n\n"
                  "** Log\n")
          (save-buffer))
        (setq schema (my/workflow-project-schema buffer))))
    (my/workflow-register-agenda-index index)
    schema))

(defun my/work-project-open (&optional project-key workspace store)
  "Open PROJECT-KEY at Docs, or browse its notes directory without an index.

With WORKSPACE non-nil, select its stable workspace tab and show the index.
Opening never creates project data or changes task bindings."
  (interactive (list nil current-prefix-arg))
  (unless project-key
    (let ((store (or store "shared")))
      (unless (my/workflow-project-choices store)
        (user-error "No notes projects exist"))
      (setq project-key (cdr (my/workflow-read-project-selection nil store t)))))
  (let* ((project-key (my/workflow-validate-project-key project-key))
         (index (my/workflow-project-index-file project-key store))
         (directory (file-name-directory index)))
    (unless (file-directory-p directory)
      (user-error "Project directory does not exist: %s" directory))
    (let* ((schema (my/workflow-prepare-project project-key directory nil store))
           (root (if schema
                     (my/workspace-canonical-directory (plist-get schema :root))
                   directory))
           (buffer (if schema (plist-get schema :buffer) (dired-noselect directory))))
      (if workspace
          (progn
            (require 'my-window-layouts)
            (unless (file-directory-p root)
              (user-error "Workspace root does not exist: %s" root))
            (let ((tabs (copy-tree (tab-bar-tabs)))
                  (windows (current-window-configuration)))
              (condition-case error-data
                  (progn
                    (my/workspace-select-or-create-tab
                     root (my/workspace-default-id root) project-key)
                    (my/tab-set-current-property 'my/layout-edit-buffer buffer)
                    (my/layout-render buffer nil)
                    (my/tab-set-current-property 'my/layout-current 'focus))
                (t
                 (set-window-configuration windows)
                 (tab-bar-tabs-set tabs)
                 (signal (car error-data) (cdr error-data))))))
        (pop-to-buffer buffer))
      (when schema
        (widen)
        (goto-char (plist-get schema :docs))
        (org-fold-show-entry))
      buffer)))

(defun my/work-project-create (&optional project-key workspace-root store)
  "Create PROJECT-KEY's empty canonical index and open Docs without a task.

An omitted WORKSPACE-ROOT uses the exact notes directory.  A selected code
workspace uses normal project-root discovery.  Existing indexes must match
both the project key and selected root."
  (interactive)
  (let* ((project-key
          (my/workflow-validate-project-key
           (or project-key (read-string "Project key: "))))
         (directory (file-name-directory (my/workflow-project-index-file project-key store)))
         (workspace-root
          (or workspace-root
              (if (called-interactively-p 'interactive)
                  (read-directory-name "Workspace directory: " directory directory nil)
                directory)))
         (selected (my/workspace-canonical-directory
                    (my/workflow-validate-one-line workspace-root "Workspace root")))
         (root (if (equal selected directory)
                   directory
                 (unless (file-directory-p selected)
                   (user-error "Workspace directory does not exist: %s" selected))
                 (my/workspace-normalize-root selected)))
         (schema (my/workflow-prepare-project project-key root nil store)))
    (when (and schema (not (equal (plist-get schema :root) root)))
      (user-error "Project root collision for %s" project-key))
    (setq schema (my/workflow-ensure-project project-key root nil store))
    (my/work-project-open project-key nil store)
    schema))

(defun my/work-project-create-select-store ()
  "Create a project after choosing shared or private storage."
  (interactive)
  (let* ((store (my/work-store-read))
         (key (my/workflow-validate-project-key (read-string "Project key: ")))
         (directory (file-name-directory (my/workflow-project-index-file key store))))
    (my/work-project-create
     key (read-directory-name "Workspace directory: " directory directory nil)
     store)))

(defun my/work-project-open-select-store ()
  "Browse a project after choosing shared or private storage."
  (interactive)
  (my/work-project-open nil current-prefix-arg (my/work-store-read)))

(defvar my/work-roam-store "shared"
  "Store currently selected for Org-roam's directory and database.")

(with-eval-after-load 'org-roam
  (cl-defmethod org-roam-node-slug :around ((node org-roam-node))
    (replace-regexp-in-string "_" "-" (cl-call-next-method))))

(defun my/work-roam-select-store (store)
  "Activate STORE's separately scoped Org-roam directory and database.

Private indexing is limited to projects because the private store also
contains legacy imports.  An unfinished capture must be finalized first."
  (require 'org-roam)
  (let ((directory (if (equal store "private")
                       (my/workflow-project-storage-directory store)
                     (my/work-store-directory store)))
        (database (expand-file-name (format "org-roam-%s.db" store)
                                    user-emacs-directory))
        (exclusions (if (equal store "private")
                        (list org-attach-id-dir "\\`imported/")
                      (list org-attach-id-dir))))
    (unless (file-directory-p directory)
      (user-error "Note store directory does not exist: %s" directory))
    (unless (and (equal org-roam-directory directory)
                 (equal org-roam-db-location database)
                 (equal org-roam-file-exclude-regexp exclusions))
      (when (seq-some (lambda (buffer)
                       (buffer-local-value 'org-capture-mode buffer))
                     (buffer-list))
        (user-error "Finish the active Org capture before switching note stores"))
      (when org-roam-db-autosync-mode
        (org-roam-db-autosync-mode -1))
      (setq org-roam-directory directory
            org-roam-db-location database
            org-roam-file-exclude-regexp exclusions
            my/work-roam-store store))
    (if org-roam-db-autosync-mode
        (org-roam-db-sync)
      (org-roam-db-autosync-mode 1))))

(defun my/work-roam-update-current-file ()
  "Update a saved note only in the currently selected Org-roam store."
  (when (and (bound-and-true-p org-roam-db-autosync-mode)
             (buffer-file-name)
             (org-roam-file-p (buffer-file-name)))
    (org-roam-db-update-file)))

(add-hook 'org-mode-hook
          (lambda ()
            (add-hook 'after-save-hook #'my/work-roam-update-current-file nil t)))

(defun my/work-roam-find-shared ()
  "Find a shared Org-roam node, capturing new titles into the shared inbox."
  (interactive)
  (my/work-roam-select-store "shared")
  (let ((node (org-roam-node-read)))
    (if (org-roam-node-file node)
        (org-roam-node-visit node current-prefix-arg)
      (my/work-roam-capture-note (org-roam-node-title node)
                                (expand-file-name "inbox/" my/work-shared-directory)
                                "shared"))))

(defun my/work-roam-find-select-store ()
  "Choose a store and find one of its Org-roam notes."
  (interactive)
  (let ((store (my/work-store-read)))
    (my/work-roam-select-store store)
    (if (equal store "shared")
        (my/work-roam-find-shared)
      (org-roam-node-visit (org-roam-node-read nil nil nil t) current-prefix-arg))))

(defun my/work-roam-insert ()
  "Insert a node link from the current file or task's note store."
  (interactive)
  (let ((store (my/workflow-current-store)))
    (my/work-roam-select-store store)
    (if (equal store "shared")
        (org-roam-node-insert)
      (let ((node (org-roam-node-read nil nil nil t)))
        (org-insert-link nil (concat "id:" (org-roam-node-id node))
                         (org-roam-node-title node))))))

(defun my/work-roam-capture-note (title directory store)
  "Capture TITLE as a new semantic filename in DIRECTORY inside STORE.

Existing files and unsaved buffers at the destination are never reused."
  (my/work-roam-select-store store)
  (let* ((title (my/workflow-validate-one-line title "Note title"))
         (node (org-roam-node-create :title title))
         (slug (my/workflow-validate-project-key (org-roam-node-slug node)))
         (file (expand-file-name (concat slug ".org") directory))
         (buffer (get-file-buffer file)))
    (when (or (file-exists-p file) (file-symlink-p file)
              (and buffer (buffer-modified-p buffer)))
      (user-error "Note destination already exists: %s" file))
    (make-directory directory t)
    (org-roam-capture-
     :node node
     :templates `(("n" "note" plain "%?"
                   :target (file+head ,(file-relative-name file org-roam-directory)
                                      "#+title: ${title}\n")
                   :unnarrowed t))
     :props '(:finalize find-file))))

(defun my/work-inbox-note-create ()
  "Create a shared inbox note without a timestamp in its filename."
  (interactive)
  (my/work-roam-capture-note (read-string "Note title: ")
                              (expand-file-name "inbox/" my/work-shared-directory)
                              "shared"))

(defun my/work-project-note-create ()
  "Choose a store and project, then capture a named Org-roam project note."
  (interactive)
  (let* ((store (my/work-store-read))
         (key (cdr (my/workflow-read-project-selection nil store t)))
         (directory (file-name-directory (my/workflow-project-index-file key store))))
    (unless (file-directory-p directory)
      (user-error "Project directory does not exist: %s" directory))
    (my/workflow-prepare-project key directory nil store)
    (my/work-roam-capture-note (read-string "Note title: ") directory store)))

(defun my/work-note-refile ()
  "Move the current Org note to a category or project while preserving IDs.

Require a saved, ordinary Org file and reject destination collisions."
  (interactive)
  (let* ((source (buffer-file-name))
         (source-store (my/work-store-for-file source)))
    (unless (and (derived-mode-p 'org-mode) source-store
                 (file-regular-p source) (not (file-symlink-p source)))
      (user-error "Visit an ordinary Org note in a note store first"))
    (when (equal (file-name-nondirectory source) "index.org")
      (user-error "Move descriptive notes, not managed project indexes"))
    (when (buffer-modified-p)
      (user-error "Save the note before moving it"))
    (let* ((store (my/work-store-read))
           (kind (if (equal store "private") "project"
                   (completing-read "Destination type: " '("project" "category") nil t)))
           (directory
            (if (equal kind "project")
                (let ((key (cdr (my/workflow-read-project-selection nil store t))))
                  (file-name-directory (my/workflow-project-index-file key store)))
              (let* ((root (expand-file-name "notes/" my/work-shared-directory))
                     (choices (when (file-directory-p root)
                                (seq-filter
                                 (lambda (name) (file-directory-p (expand-file-name name root)))
                                 (directory-files root nil directory-files-no-dot-files-regexp))))
                     (category (my/workflow-validate-project-key
                                (completing-read "Category: " choices nil nil))))
                (expand-file-name (file-name-as-directory category) root))))
           (destination (expand-file-name (file-name-nondirectory source) directory))
           (buffer (get-file-buffer destination)))
      (when (or (file-exists-p destination) (file-symlink-p destination)
                (and buffer (buffer-modified-p buffer)))
        (user-error "Note destination already exists: %s" destination))
      (make-directory directory t)
      (my/work-roam-select-store source-store)
      (rename-file source destination nil)
      (set-visited-file-name destination t)
      (org-roam-db-sync)
      (my/work-roam-select-store store)
      (org-id-update-id-locations (list destination) t)
      (message "Moved note to %s" destination))))

(defun my/workflow-task-at-position (schema position)
  "Return the managed task in SCHEMA at headline POSITION, or nil."
  (with-current-buffer (plist-get schema :buffer)
    (save-excursion
      (goto-char position)
      (org-back-to-heading t)
      (let ((id (org-entry-get nil "ID"))
            (state (org-get-todo-state)))
        (when (and id state (member state org-todo-keywords-1))
          (list :id id
                :title (org-get-heading t t t t)
                :state state
                :key (org-entry-get nil "WORK_KEY")
                :root (org-entry-get nil "WORKSPACE_ROOT")
                :note-file (org-entry-get nil "NOTE_FILE")
                :project-id (plist-get schema :id)
                :project-key (plist-get schema :key)
                :project-root (plist-get schema :root)
                :store (plist-get schema :store)
                :file (buffer-file-name)
                :position (copy-marker (point))))))))

(defun my/workflow-tasks (schema &optional archive)
  "Return managed direct tasks in SCHEMA's Active or ARCHIVE branch."
  (let ((position (plist-get schema (if archive :archive :active)))
        result)
    (with-current-buffer (plist-get schema :buffer)
      (dolist (child (my/workflow-heading-children position))
        (let ((task (my/workflow-task-at-position schema (cdr child))))
          (when task
            (push task result)))))
    (nreverse result)))

(defun my/workflow-find-task-by-key (schema work-key &optional include-archive)
  "Return SCHEMA's task with project-scoped WORK-KEY, if any."
  (seq-find (lambda (task) (equal (plist-get task :key) work-key))
            (append (my/workflow-tasks schema)
                    (when include-archive (my/workflow-tasks schema t)))))

(defun my/workflow-find-task (task-id)
  "Find TASK-ID across discovered canonical indexes, returning a task plist."
  (let (result)
    (dolist (index (my/workflow-discover-project-indexes))
      (unless result
        (let ((schema (my/workflow-project-schema (find-file-noselect index))))
          (setq result
                (seq-find (lambda (task) (equal (plist-get task :id) task-id))
                          (append (my/workflow-tasks schema)
                                  (my/workflow-tasks schema t)))))))
    result))

(defun my/workflow-current-task ()
  "Return the active task projected into the current tab, or signal an error."
  (let ((task-id (my/tab-current-property 'my/work-task-id)))
    (unless task-id
      (user-error "The current tab has no active work task"))
    (or (my/workflow-find-task task-id)
        (user-error "The active work task no longer exists"))))

(defun my/workflow-current-context ()
  "Return the current provider-neutral task and workspace context plist."
  (let ((task (my/workflow-current-task)))
    (list :task task
          :task-id (plist-get task :id)
          :project-key (plist-get task :project-key)
          :workspace-id (my/tab-current-property 'my/workspace-id)
          :workspace-root (or (my/tab-current-property 'my/workspace-root)
                              (plist-get task :root)))))

(defun my/workflow-task-set-property (task property value)
  "Set TASK's PROPERTY to VALUE, deleting it when VALUE is nil."
  (with-current-buffer (find-file-noselect (plist-get task :file))
    (save-excursion
      (goto-char (plist-get task :position))
      (org-back-to-heading t)
      (if value
          (org-entry-put nil property value)
        (org-entry-delete nil property)))))

(defun my/workflow-save-buffer (buffer)
  "Save BUFFER as one explicit workflow transaction boundary."
  (with-current-buffer buffer
    (save-buffer)))

(defun my/workflow-work-key (schema)
  "Generate SCHEMA's first available timestamp-based local task key."
  (let* ((base (format-time-string "work-%Y%m%d-%H%M%S"))
         (candidate base)
         (suffix 2))
    (while (my/workflow-find-task-by-key schema candidate t)
      (setq candidate (format "%s-%d" base suffix)
            suffix (1+ suffix)))
    candidate))

(defun my/workflow-valid-note-file (note-file)
  "Return NOTE-FILE's expanded path when it is an existing Org or Markdown file."
  (let ((note-file (expand-file-name note-file)))
    (unless (and (file-regular-p note-file)
                 (string-match-p "\\.\\(?:org\\|md\\)\\'" note-file))
      (user-error "Detail note must be an existing .org or .md file"))
    note-file))

(defun my/workflow-task-label (task)
  "Return TASK's human-readable cross-project journal label."
  (format "%s/%s"
          (plist-get task :project-key)
          (or (plist-get task :key) (plist-get task :id))))

(defun my/workflow-date (time)
  "Return TIME as a Gregorian date for Org datetree functions."
  (calendar-gregorian-from-absolute (time-to-days time)))

(defun my/workflow-work-log-heading (time)
  "Move point to TIME's sole Work log heading, creating it in the current buffer."
  (org-datetree-find-date-create (my/workflow-date time))
  (let ((day (point))
        (level (org-outline-level))
        (work-logs
         (seq-filter (lambda (child) (equal (car child) "Work log"))
                     (my/workflow-heading-children (point)))))
    (when (> (length work-logs) 1)
      (user-error "Today's Work log has duplicates; combine them before logging"))
    (if work-logs
        (goto-char (cdr (car work-logs)))
      (goto-char day)
      (org-end-of-subtree t)
      (insert "\n")
      (insert (make-string (1+ level) ?*) " Work log\n")
      (goto-char (line-beginning-position)))
    (point)))

(defun my/workflow-journal-start-exists-p (task time)
  "Return non-nil when TASK already has today's automatic start entry."
  (let ((journal (my/workflow-journal-file (plist-get task :store) time)))
    (when (file-exists-p journal)
      (with-current-buffer (find-file-noselect journal)
        (org-mode)
        (org-with-wide-buffer
         (save-excursion
           (my/workflow-work-log-heading time)
           (let ((end (save-excursion (org-end-of-subtree t))))
             (re-search-forward
              (concat "\\[\\[id:" (regexp-quote (plist-get task :id))
                      "\\]\\[[^]]+\\]\\] start:")
              end t))))))))

(defun my/workflow-append-journal-entry (task kind text &optional time deduplicate-start)
  "Append TASK's reviewed KIND and TEXT to the global daily Work log.

When DEDUPLICATE-START is non-nil, leave an existing automatic start entry in
place so an interrupted post-save tab commit can be retried safely."
  (unless (memq kind my/workflow-log-kinds)
    (user-error "Unsupported work-log kind: %s" kind))
  (my/work-store-directory (plist-get task :store))
  (let* ((text (my/workflow-validate-one-line text "Work-log text"))
         (time (or time (current-time)))
         (journal (my/workflow-journal-file (plist-get task :store) time))
         (buffer (progn
                   (make-directory (file-name-directory journal) t)
                   (find-file-noselect journal)))
         inserted)
    (with-current-buffer buffer
      (org-mode)
      (unless (and deduplicate-start
                   (eq kind 'start)
                   (my/workflow-journal-start-exists-p task time))
        (my/workflow-work-log-heading time)
        (org-end-of-subtree t)
        (unless (bolp)
          (newline))
        (let ((note-file (plist-get task :note-file)))
          (insert (concat (format "- [%s] [[id:%s][%s]] %s: %s"
                                  (format-time-string "%H:%M" time)
                                  (plist-get task :id)
                                  (my/workflow-task-label task)
                                  (symbol-name kind)
                                  (string-trim text))
                          (when note-file
                            (format " [[file:%s][%s]]"
                                    note-file
                                    (file-name-nondirectory note-file)))
                          "\n"))
          (setq inserted t))))
    (list :buffer buffer :inserted inserted)))

(defun my/workflow-prepare-task-binding (task root)
  "Validate TASK's ROOT binding and any existing root tab before writes."
  (let* ((task-root (and task (plist-get task :root)))
         (task-id (and task (plist-get task :id)))
         (current-index
          (cl-loop for tab in (tab-bar-tabs)
                   for index from 1
                   when (eq (car tab) 'current-tab)
                   return index))
         (tab-index
          (or (and task-id (my/workspace-task-tab-index root task-id))
              (and (equal (my/tab-current-property 'my/workspace-root) root)
                   current-index)
              (my/workspace-tab-index root))))
    (when (and task-root (not (equal task-root root))
               (not (y-or-n-p
                     (format "Rebind task %s from %s to %s? "
                             (plist-get task :id) task-root root))))
      (user-error "Task remains bound to %s" task-root))
    (when (and tab-index
               (let ((tab-task-id
                      (alist-get 'my/work-task-id
                                 (cdr (nth (1- tab-index) (tab-bar-tabs))))))
                 (and tab-task-id
                      (not (equal tab-task-id task-id))))
               (not (y-or-n-p "Rebind this workspace tab to the selected task? ")))
      (user-error "Workspace tab binding was not changed"))))

(defun my/workflow-commit-task-tab (root task-id)
  "Bind ROOT's tab to TASK-ID, restoring the complete tab state on failure."
  (let ((tabs (copy-tree (tab-bar-tabs))))
    (condition-case err
        (progn
          (let ((index (my/workspace-task-tab-index root task-id)))
            (if index
                (tab-bar-select-tab index)
              (unless (equal (my/tab-current-property 'my/workspace-root) root)
                (my/workspace-select-or-create-tab root))))
          (my/tab-set-current-property 'my/work-task-id task-id))
      (t
       (tab-bar-tabs-set tabs)
       (signal (car err) (cdr err))))))

(defun my/workflow-open-task (task)
  "Open TASK's existing detail note, or its Org heading when no note is linked."
  (let ((note-file (plist-get task :note-file)))
    (if note-file
        (find-file note-file)
      (pop-to-buffer (find-file-noselect (plist-get task :file)))
      (goto-char (plist-get task :position))
      (org-back-to-heading t)
      (org-fold-show-entry))))

(defun my/work-start (&optional title workspace-root project-key work-key note-file store)
  "Select or create local work, record its first start, and bind its task tab.

TITLE may name an existing active task or create one.  WORKSPACE-ROOT,
PROJECT-KEY, WORK-KEY, and NOTE-FILE make the command directly usable by
capture and tests; interactive use derives and prompts for the missing values."
  (interactive)
  (let* ((current-root (my/tab-current-property 'my/workspace-root))
         (root (if (and current-root (null workspace-root))
                   current-root
                 (my/workspace-normalize-root
                  (or workspace-root default-directory))))
         (selection
          (when (and (not project-key) (called-interactively-p 'interactive))
            (my/workflow-read-project-selection root store)))
         (store (or store (car selection) "shared"))
         (project-key
          (my/workflow-validate-project-key
           (or project-key
               (cdr selection)
               (my/workflow-project-key-for-root root))))
         (title (and title (my/workflow-validate-one-line title "Task title")))
         (work-key (and work-key (my/workflow-validate-one-line work-key "Work key")))
         (note-file (and note-file (my/workflow-valid-note-file note-file)))
         (schema (my/workflow-prepare-project project-key root t store))
         (task
          (cond
           ((and schema work-key)
            (my/workflow-find-task-by-key schema work-key))
           ((and schema title (string-prefix-p "id:" title))
            (seq-find (lambda (candidate)
                        (equal (plist-get candidate :id) (substring title 3)))
                      (my/workflow-tasks schema)))
           ((and schema title)
            (seq-find (lambda (candidate) (equal (plist-get candidate :title) title))
                      (my/workflow-tasks schema)))))
         root-tab-index
         already-bound)
    (when (and schema (not task) (not title) (called-interactively-p 'interactive))
      (let* ((tasks (my/workflow-tasks schema))
             (choices
              (append
               '("Create a new task")
               (mapcar (lambda (candidate)
                         (format "%s | %s"
                                 (or (plist-get candidate :key) "(no key)")
                                 (plist-get candidate :title)))
                       tasks)))
             (choice (completing-read "Task: " choices nil t)))
        (if (equal choice "Create a new task")
            (setq title (my/workflow-validate-one-line
                         (read-string "Task title: ") "Task title"))
          (setq task
                (nth (1- (cl-position choice choices :test #'equal)) tasks)))))
    (when (and (not schema) (not title) (called-interactively-p 'interactive))
      (setq title (my/workflow-validate-one-line
                   (read-string "Task title: ") "Task title")))
    (when (and title (string-prefix-p "id:" title) (not task))
      (user-error "Active task %s does not exist" (substring title 3)))
    (unless (or task title)
      (user-error "Task title is required"))
    (when (and schema work-key (not task)
               (my/workflow-find-task-by-key schema work-key t))
      (user-error "Work key %s already exists in this project" work-key))
    (setq root-tab-index (and task
                              (my/workspace-task-tab-index root
                                                           (plist-get task :id)))
          already-bound
          (and task
               root-tab-index
               (equal (alist-get 'my/work-task-id
                                  (cdr (nth (1- root-tab-index) (tab-bar-tabs))))
                      (plist-get task :id))))
    (unless already-bound
      (my/workflow-prepare-task-binding task root)
      (setq schema (or schema (my/workflow-ensure-project project-key root nil store)))
      (unless task
        (with-current-buffer (plist-get schema :buffer)
          (save-excursion
            (goto-char (plist-get schema :active))
            (org-end-of-subtree t)
            (insert "\n**** TODO " title "\n")
            (org-back-to-heading t)
            (org-id-get-create)
            (setq task (my/workflow-task-at-position schema (point))))))
      (when (and work-key (not (equal (plist-get task :key) work-key)))
        (when (and (my/workflow-find-task-by-key schema work-key t)
                   (not (equal (plist-get task :key) work-key)))
          (user-error "Work key %s already exists in this project" work-key))
        (my/workflow-task-set-property task "WORK_KEY" work-key))
      (unless (or work-key (plist-get task :key))
        (my/workflow-task-set-property task "WORK_KEY" (my/workflow-work-key schema)))
      (unless (equal (plist-get task :root) root)
        (my/workflow-task-set-property task "WORKSPACE_ROOT" root))
      (when note-file
        (my/workflow-task-set-property task "NOTE_FILE" note-file))
      (setq task (my/workflow-task-at-position schema (plist-get task :position)))
      (my/workflow-save-buffer (plist-get schema :buffer))
      (let ((journal-result
             (my/workflow-append-journal-entry task 'start "Started work." nil t)))
        (my/workflow-save-buffer (plist-get journal-result :buffer)))
      (my/workflow-commit-task-tab root (plist-get task :id)))
    (when already-bound
      (tab-bar-select-tab root-tab-index))
    (my/workflow-open-task task)
    task))

(defun my/work-open ()
  "Open the current tab's active task or effective detail note."
  (interactive)
  (my/workflow-open-task (my/workflow-current-task)))

(defun my/work-log (kind text &optional task)
  "Append reviewed TEXT with explicit KIND for TASK or the active tab task.

TASK is accepted only from a caller that has already verified its durable Org
identity.  This lets a selected agent event prefill a reviewed log without
switching tabs or mutating task state automatically."
  (interactive
   (list (intern (completing-read "Log kind: " my/workflow-log-kinds nil t))
         (read-string "Work log: ")))
  (let ((task (or task (my/workflow-current-task))))
    (let ((journal-result (my/workflow-append-journal-entry task kind text)))
      (my/workflow-save-buffer (plist-get journal-result :buffer)))))

(defun my/work-bind-note (note-file)
  "Bind an existing Org or Markdown NOTE-FILE to the active task."
  (interactive "fDetail note: ")
  (let* ((note-file (my/workflow-valid-note-file note-file))
         (task (my/workflow-current-task)))
    (my/workflow-task-set-property task "NOTE_FILE" note-file)
    (my/workflow-save-buffer (find-file-noselect (plist-get task :file)))
    (my/work-open)))

(defun my/work-set-state (state)
  "Set the active task's local Org TODO STATE explicitly."
  (interactive
   (list (completing-read "TODO state: " org-todo-keywords-1 nil t)))
  (let ((task (my/workflow-current-task)))
    (with-current-buffer (find-file-noselect (plist-get task :file))
      (save-excursion
        (goto-char (plist-get task :position))
        (org-back-to-heading t)
        (org-todo state))
      (my/workflow-save-buffer (current-buffer)))))

(defun my/work-project-log (text)
  "Append reviewed project-level TEXT to the active task's dated project Log."
  (interactive (list (read-string "Project log: ")))
  (let* ((text (my/workflow-validate-one-line text "Project-log text"))
         (task (my/workflow-current-task))
         (buffer (find-file-noselect (plist-get task :file)))
         (schema (my/workflow-project-schema buffer))
         (time (current-time)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (plist-get schema :log))
        (org-datetree-find-date-create (my/workflow-date time) 'subtree-at-point)
        (org-end-of-subtree t)
        (unless (bolp)
          (newline))
        (insert "\n" (make-string (1+ (org-outline-level)) ?*) " "
                (format-time-string "%H:%M" time) " "
                (format "[[id:%s][%s]] %s\n"
                        (plist-get task :id)
                        (my/workflow-task-label task)
                        (string-trim text)))))
    (my/workflow-save-buffer buffer)))

(defun my/work-archive ()
  "Move a completed or canceled active task into its project's Archive branch."
  (interactive)
  (let* ((task (my/workflow-current-task))
         (buffer (find-file-noselect (plist-get task :file)))
         (schema (my/workflow-project-schema buffer)))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (plist-get task :position))
        (org-back-to-heading t)
        (unless (org-entry-is-done-p)
          (user-error "Only completed or canceled tasks may be archived"))
        (org-cut-subtree)
        (setq schema (my/workflow-project-schema buffer))
        (goto-char (plist-get schema :archive))
        (org-end-of-subtree t)
        (newline)
        (org-paste-subtree 4)))
    (my/workflow-save-buffer buffer)))

(defun my/workflow-sanitize-draft-text (text)
  "Remove local property drawers and local or TRAMP link targets from TEXT."
  (let (lines result in-property-drawer)
    (dolist (line (split-string text "\n"))
      (cond
       ((string-match-p "^[ \\t]*:PROPERTIES:[ \\t]*$" line)
        (setq in-property-drawer t))
       ((and in-property-drawer
             (string-match-p "^[ \\t]*:END:[ \\t]*$" line))
        (setq in-property-drawer nil))
       ((not in-property-drawer)
        (push line lines))))
    (setq result (string-join (nreverse lines) "\n"))
    (setq result
          (replace-regexp-in-string
           "\\[\\[\\([^]\n]+\\)\\]\\(?:\\[\\([^]\n]*\\)\\]\\)?\\]"
           (lambda (link)
             (save-match-data
               (string-match
                "\\`\\[\\[\\([^]\n]+\\)\\]\\(?:\\[\\([^]\n]*\\)\\]\\)?\\]\\'"
                link)
               (let ((target (match-string 1 link))
                     (label (match-string 2 link)))
                 (if (or (string-prefix-p "file:" target)
                         (file-remote-p target)
                         (string-prefix-p "/" target)
                         (string-prefix-p "~/" target))
                     (or label "local link")
                   link))))
           result t t))
    result))

(defun my/workflow-draft-sensitive-p (text)
  "Return non-nil when TEXT still resembles a path or common credential form."
  (string-match-p
   "\\(?:~[/\\\\]\\|/[[:alnum:]_.-]+/\\|/[[:alnum:]_.-]+:[^[:space:]]*\\|\\b\\(?:api[_-]?key\\|token\\|secret\\|password\\)\\b\\)"
   text))

(defvar my/work-draft-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-c C-c" #'my/work-draft-finalize)
    map)
  "Keymap for editable provider-neutral work update drafts.")

(define-derived-mode my/work-draft-mode text-mode "Work-Draft"
  "Major mode for reviewed, generic work-status drafts.")

(defun my/work-draft-finalize ()
  "Copy this reviewed draft, requiring acknowledgement for warning content."
  (interactive)
  (let ((text (buffer-substring-no-properties (point-min) (point-max))))
    (when (my/workflow-draft-sensitive-p text)
      (message "Warning: the current draft may contain a local path or credential term")
      (unless (y-or-n-p "Current draft may contain a local path or credential term. Copy anyway? ")
        (user-error "Draft was not copied")))
    (kill-new text)
    (message "Work update draft copied")))

(defun my/workflow-draft-source-items (task schema)
  "Return TASK and SCHEMA's individually selectable draft-source plists."
  (let* ((buffer (find-file-noselect (plist-get task :file)))
         (task-id (plist-get task :id))
         (task-link-regexp
          (concat "\\[\\[id:" (regexp-quote task-id) "\\]\\[[^]]+\\]\\]"))
         (items nil)
         (docs-index 0)
         (log-index 0)
         (journal-index 0))
    (with-current-buffer buffer
      (save-excursion
        (goto-char (plist-get task :position))
        (org-back-to-heading t)
        (setq items
              (list
               (list :label "Task text"
                     :section 'changed
                     :text
                     (buffer-substring-no-properties
                      (progn (forward-line 1) (point))
                      (save-excursion (org-end-of-subtree t))))))
        (goto-char (plist-get schema :docs))
        (let ((docs (org-element-at-point)))
          (when (org-element-property :contents-begin docs)
            (save-restriction
              (narrow-to-region (org-element-property :contents-begin docs)
                                (org-element-property :contents-end docs))
              (org-element-map (org-element-parse-buffer) 'item
                (lambda (item)
                  (setq docs-index (1+ docs-index))
                  (let ((text (buffer-substring-no-properties
                               (org-element-property :begin item)
                               (org-element-property :end item))))
                    (setq items
                          (append
                           items
                           (list
                            (list :label
                                  (format "Docs %d: %s" docs-index
                                          (string-trim
                                           (replace-regexp-in-string "[\n\r]+" " " text)))
                                  :section 'evidence
                                  :text text))))))))))
        (goto-char (plist-get schema :log))
        (org-map-entries
         (lambda ()
           (let ((heading (org-get-heading t t t t)))
             (when (string-match-p task-link-regexp heading)
               (setq log-index (1+ log-index))
               (let ((text (buffer-substring-no-properties
                            (line-beginning-position)
                            (save-excursion (org-end-of-subtree t)))))
                 (setq items
                       (append
                        items
                        (list
                         (list :label (format "Project Log %d: %s" log-index heading)
                               :section 'evidence
                               :text text))))))))
         nil 'tree)))
    (let ((journal (my/workflow-journal-file (plist-get task :store))))
      (when (file-exists-p journal)
        (with-temp-buffer
          (insert-file-contents journal)
          (org-mode)
          (save-excursion
            (my/workflow-work-log-heading (current-time))
            (let ((start (point))
                  (end (save-excursion (org-end-of-subtree t))))
              (dolist (line (split-string
                             (buffer-substring-no-properties start end) "\n" t))
                (when (and (string-match-p "^[-+][[:space:]]" line)
                           (string-match-p task-link-regexp line))
                  (setq journal-index (1+ journal-index))
                  (setq items
                        (append
                         items
                         (list
                          (list :label (format "Journal %d: %s" journal-index line)
                                :section 'evidence
                                :text line)))))))))))
    items))

(defun my/work-draft-update (&optional sources)
  "Create an editable generic update from explicitly selected SOURCES.

SOURCES is a list returned by `my/workflow-draft-source-items'.  Interactive
use selects individual task text, Docs items, project Log entries, and today's
current-task journal entries."
  (interactive
   (let* ((task (my/workflow-current-task))
          (buffer (find-file-noselect (plist-get task :file)))
          (schema (my/workflow-project-schema buffer))
          (items (my/workflow-draft-source-items task schema))
          (labels (mapcar (lambda (item) (plist-get item :label)) items))
          (selected (completing-read-multiple "Include sources: " labels nil t)))
     (list
      (seq-filter (lambda (item) (member (plist-get item :label) selected)) items))))
  (let* ((task (my/workflow-current-task))
         (changed (format "Changed\n- %s\n" (plist-get task :title)))
         (evidence "\nEvidence\n- "))
    (dolist (source sources)
      (if (eq (plist-get source :section) 'changed)
          (setq changed (concat changed "\nTask context\n" (plist-get source :text)))
        (setq evidence (concat evidence "\n" (plist-get source :text) "\n"))))
    (let* ((text
            (my/workflow-sanitize-draft-text
             (concat changed
                     (format "\nCurrent status or blocker\n- Org state: %s\n"
                             (or (plist-get task :state) "none"))
                     evidence
                     "\nNext step\n- \n")))
           (draft (get-buffer-create "*Work Update Draft*")))
      (with-current-buffer draft
        (erase-buffer)
        (insert text)
        (my/work-draft-mode)
        (when (my/workflow-draft-sensitive-p text)
          (message "Warning: review local paths or credential-like text before sharing.")))
      (pop-to-buffer draft))))

(defun my/work-capture-target ()
  "Move Org capture to the current project's canonical Tasks/Active heading."
  (let* ((root (my/workspace-normalize-root default-directory))
         (selection (my/workflow-read-project-selection root))
         (store (car selection))
         (project-key (cdr selection))
         (schema (my/workflow-ensure-project project-key root t store))
         (buffer (plist-get schema :buffer)))
    (set-buffer buffer)
    (goto-char (plist-get schema :active))
    (org-end-of-subtree t)
    (point)))

(provide 'my-workflow)

;;; my-workflow.el ends here
