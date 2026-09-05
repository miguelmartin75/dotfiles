;;; my-window-layouts.el --- Deterministic task workspace layouts -*- lexical-binding: t; -*-

;;; Commentary:

;; Layouts are recipes over buffers and durable terminal descriptors.  The
;; workflow module owns workspace identity and task state; this module only
;; owns the tab-local runtime state required to render a workspace.

;;; Code:

(require 'cl-lib)
(require 'dired)
(require 'project)
(require 'subr-x)
(require 'tab-bar)
(require 'tramp)
(require 'my-send-text)
(require 'my-workflow)

(declare-function ghostel-create "ghostel" (&optional name display identity))
(declare-function ghostel-project "ghostel" (&optional arg))
(declare-function gptel "gptel" (&optional buffer-name interactive prefix))
(declare-function magit-status-setup-buffer "magit" (directory &optional initial-section))
(declare-function term-sessions-open "term-sessions-frontends" (name &optional command))
(declare-function term-sessions-open-with-frontend "term-sessions-frontends"
                  (name &optional command frontend allow-create))
(declare-function term-sessions-read-existing-session-entry "term-sessions-frontends"
                  (&optional prompt))

(defgroup my/window-layouts nil
  "Deterministic workspace layouts."
  :group 'convenience)

(defcustom my/window-layouts
  '((focus
     :key "e"
     :label "Focus edit")
    (terminal
     :key "T"
     :label "Edit + terminal"
     :buffer-function my/layout-terminal-buffer
     :provider auto
     :session nil
     :command nil)
    (agent
     :key "A"
     :label "Edit + coding agent"
     :buffer-function my/layout-agent-buffer
     :backend terminal-agent
     :session my/layout-agent-session-name
     :command ("codex"))
    (gptel
     :key "G"
     :label "Edit + Gptel"
     :buffer-function my/layout-gptel-buffer
     :buffer nil)
    (magit
     :key "M"
     :label "Edit + Magit"
     :buffer-function my/layout-magit-buffer))
  "Named layout recipes and provider settings.

The terminal `:provider' may be `auto', `project-ghostel', `folder-ghostel',
`existing-zmx', or `new-zmx'.  A zmx `:session' is nil for an existing-session
selection, a string for an intentionally shared session, or a function of the
layout name and normalized root.  Automatic agent sessions include the
verified work-task identity as well as the normalized-root hash, so rebinding
one worktree cannot reopen the prior task's agent process.  Commands are argv
lists, or one executable string, so owned launch commands can quote every argv
component safely."
  :type 'sexp)

(defvar my/layout-codex-native-launcher nil
  "Optional local-native Codex launcher.

The launcher is explicitly registered with
`my/layout-register-codex-native-launcher'.  It receives a normalized local
workspace root and the current workflow task plist, and returns a live buffer.
This core module neither requires nor probes an optional Codex package.")

(defvar my/layout-provider-terminal-target nil
  "Dynamically collected terminal target for one provider resolution.")

(defvar my/layout-provider-agent-target nil
  "Dynamically collected coding-agent target for one provider resolution.")

(defvar my/layout-provider-agent-backend nil
  "Dynamically collected coding-agent backend for one provider resolution.")

(defconst my/layout-clear-target (make-symbol "my/layout-clear-target")
  "Sentinel requesting removal of a cached terminal target after rendering.")

(defun my/layout-register-codex-native-launcher (launcher)
  "Register local-native Codex LAUNCHER, or clear it with nil.

LAUNCHER must accept a normalized local workspace root and the current task
plist, then return its live session buffer."
  (when (and launcher (not (functionp launcher)))
    (user-error "Native Codex launcher must be a function"))
  (setq my/layout-codex-native-launcher launcher))

(defun my/layout-entry (layout)
  "Return LAYOUT's provider settings plist or signal an actionable error."
  (or (cdr (assq layout my/window-layouts))
      (user-error "Unknown workspace layout %s" layout)))

(defun my/layout-session-name (root role)
  "Return a root-scoped zmx name for ROOT and ROLE."
  (let* ((basename (file-name-nondirectory (directory-file-name root)))
         (basename (replace-regexp-in-string "[^[:alnum:]]+" "-" basename))
         (basename (string-trim basename "-+" "-+"))
         (basename (if (string-empty-p basename) "workspace" basename)))
    (format "%s-%s-%s"
            (downcase basename)
            (symbol-name role)
            (substring (secure-hash 'sha1 root) 0 8))))

(defun my/layout-agent-session-name (_layout root)
  "Return ROOT and verified-task scoped terminal-agent zmx name.

A task-bound workspace gets a task-distinct durable name.  Unbound workspaces
retain the root-scoped name so intentional worktree isolation still applies."
  (let ((task-id (my/layout-task-id-for-root root)))
    (if task-id
        (format "%s-%s"
                (my/layout-session-name root 'agent)
                (substring (secure-hash 'sha1 task-id) 0 8))
      (my/layout-session-name root 'agent))))

(defun my/layout-zmx-cwd (root)
  "Return ROOT in the form expected by zmx session metadata."
  (or (file-remote-p root 'localname) root))

(defun my/layout-zmx-target (root name)
  "Return an owned zmx descriptor for ROOT named NAME."
  (list :type 'zmx
        :name name
        :directory root
        :cwd (my/layout-zmx-cwd root)))

(defun my/layout-zmx-target-p (target)
  "Return non-nil when TARGET is a zmx descriptor with a usable name."
  (and (listp target)
       (eq (plist-get target :type) 'zmx)
       (stringp (plist-get target :name))
       (not (string-empty-p (plist-get target :name)))))

(defun my/layout-ghostel-target (buffer)
  "Return BUFFER's complete live Ghostel target descriptor, or nil."
  (let ((result (list :type 'ghostel
                      :buffer buffer
                      :process (get-buffer-process buffer))))
    (when (my/ghostel-target-live-p result)
      result)))

(defun my/layout-entry-cwd (entry)
  "Return ENTRY's `:cwd' qualified as an Emacs directory, or nil."
  (let ((cwd (plist-get entry :cwd))
        (directory (plist-get entry :directory)))
    (when cwd
      (file-name-as-directory
       (cond
        ((file-remote-p cwd) cwd)
        ((file-remote-p directory)
         (concat (file-remote-p directory) cwd))
        (t cwd))))))

(defun my/layout-target-matches-root-p (target root)
  "Return non-nil when TARGET's advertised cwd is the normalized ROOT."
  (let ((cwd (my/layout-entry-cwd target)))
    (and cwd
         (equal (my/workspace-normalize-root cwd) root))))

(defun my/layout-validate-target-root (target root literal-session-p)
  "Validate TARGET against ROOT unless LITERAL-SESSION-P requests sharing."
  (unless (or literal-session-p
              (my/layout-target-matches-root-p target root))
    (user-error "Selected zmx session belongs to %s, not workspace %s"
                (my/layout-entry-cwd target) root))
  target)

(defun my/layout-workflow-task-for-root (root)
  "Return the current task only when it is bound to normalized ROOT."
  (let ((root (my/workspace-normalize-root root))
        task)
    (condition-case nil
        (setq task (my/workflow-current-task))
      (user-error nil))
    (when (and task
               (stringp (plist-get task :id))
               (not (string-empty-p (plist-get task :id)))
               (equal (plist-get task :root) root))
      task)))

(defun my/layout-task-id-for-root (root)
  "Return ROOT's verified current work-task identity, or nil."
  (plist-get (my/layout-workflow-task-for-root root) :id))

(defun my/layout-agent-command (entry root)
  "Return ENTRY's safely quoted Codex command for a newly created ROOT session."
  (let* ((command (plist-get entry :command))
         (argv (cond
                ((stringp command) (list command))
                ((and (listp command) command) command)
                (t nil)))
         (task (my/layout-workflow-task-for-root root))
         (remote-root-p (and (file-remote-p root)
                             (equal root (file-name-as-directory root))))
         (workspace-root (my/layout-zmx-cwd root))
         (relay-socket (when (and remote-root-p
                                  (fboundp 'my/agent-events-relay-socket-for-root))
                         (my/agent-events-relay-socket-for-root root)))
         (environment
          (append
           (when task
             (list (concat "EMACS_WORK_TASK_ID=" (plist-get task :id))
                   (concat "EMACS_WORKSPACE_ROOT="
                           (if remote-root-p
                               (if (equal workspace-root "/")
                                   "/"
                                 (directory-file-name workspace-root))
                             workspace-root))))
           (when (and (stringp relay-socket)
                      (not (string-empty-p relay-socket)))
             (list (concat "EMACS_AGENT_EVENT_SOCKET=" relay-socket))))))
    (unless argv
      (user-error "Configured terminal-agent session needs an explicit command"))
    (unless (seq-every-p #'stringp argv)
      (user-error "Terminal-agent command must be an argv list of strings"))
    (mapconcat
     #'shell-quote-argument
     (append (when environment (cons "env" environment)) argv)
     " ")))

(defun my/layout-cached-companion (layout)
  "Return LAYOUT's live cached companion buffer, or nil."
  (let ((buffer (alist-get layout (my/tab-current-property 'my/layout-companion-buffers))))
    (and (buffer-live-p buffer) buffer)))

(defun my/layout-project-p (root)
  "Return non-nil when ROOT resolves to a project without prompting."
  (let ((default-directory root))
    (project-current nil root)))

(defun my/layout-buffer-belongs-to-root-p (buffer root)
  "Return non-nil when ordinary BUFFER belongs to workspace ROOT."
  (with-current-buffer buffer
    (let* ((directory default-directory)
           (project (project-current nil directory)))
      (if project
          (equal (my/workspace-normalize-root (project-root project)) root)
        (string-prefix-p root (file-name-as-directory (expand-file-name directory)))))))

(defun my/layout-edit-buffer (root)
  "Resolve the primary edit buffer for ROOT without changing visible windows."
  (let* ((window (selected-window))
         (role (window-parameter window 'my/layout-role))
         (selected (window-buffer window))
         (stored (my/tab-current-property 'my/layout-edit-buffer)))
    (cond
     ((null role)
      (cond
       ((and (with-current-buffer selected
               (derived-mode-p 'special-mode))
             (not (with-current-buffer selected
                    (derived-mode-p 'dired-mode))))
        (if (buffer-live-p stored)
            stored
          (user-error "Workspace %s has no usable edit buffer" root)))
       ((my/layout-buffer-belongs-to-root-p selected root)
        selected)
       (t
        (user-error "Selected buffer does not belong to workspace %s; use my/workspace-select to change roots" root))))
     ((eq role 'edit)
      (if (and (with-current-buffer selected
                 (not (derived-mode-p 'special-mode)))
               (my/layout-buffer-belongs-to-root-p selected root))
          selected
        (if (buffer-live-p stored)
            stored
          (user-error "Workspace %s has no usable edit buffer" root))))
     ((buffer-live-p stored)
      stored)
     (t
      (user-error "Workspace %s has no usable edit buffer" root)))))

(defun my/layout-initial-root ()
  "Infer a root from an ordinary selected edit buffer, without changing a tab."
  (let ((window (selected-window)))
    (when (eq (window-parameter window 'my/layout-role) 'companion)
      (user-error "Select a workspace with my/workspace-select before applying a layout"))
    (let ((buffer (window-buffer window)))
      (when (and (derived-mode-p 'special-mode)
                 (not (derived-mode-p 'dired-mode)))
        (user-error "Select an ordinary edit buffer or use my/workspace-select"))
      (with-current-buffer buffer
        (my/workspace-normalize-root default-directory)))))

(defun my/layout-root ()
  "Return the current workspace root, deferring first-root tab commitment."
  (or (my/tab-current-property 'my/workspace-root)
      (my/layout-initial-root)))

(defun my/layout-terminal-provider (entry)
  "Return ENTRY's terminal provider choice, prompting only when configured nil."
  (or (plist-get entry :provider)
      (intern
       (completing-read
        "Terminal provider: "
        '("project-ghostel" "folder-ghostel" "existing-zmx" "new-zmx")
        nil t))))

(defun my/layout-terminal-buffer (entry force)
  "Resolve ENTRY's plain-terminal companion, preserving its durable descriptor."
  (let* ((root (my/layout-root))
         (cached (and (not force) (my/layout-cached-companion 'terminal)))
         (cached-target (my/tab-current-property 'my/layout-terminal-target))
         (provider (my/layout-terminal-provider entry))
         (cached-zmx-target
          (and (not force)
               (memq provider '(existing-zmx new-zmx))
               (my/layout-zmx-target-p cached-target)
               (my/layout-target-matches-root-p cached-target root)
               cached-target))
         target result)
    (when (eq provider 'auto)
      (setq provider (if (my/layout-project-p root)
                         'project-ghostel
                       'folder-ghostel)))
    (cond
     ((and cached
           (or (and (memq provider '(project-ghostel folder-ghostel))
                    (listp cached-target)
                    (eq (plist-get cached-target :type) 'ghostel)
                    (eq (plist-get cached-target :buffer) cached)
                    (my/ghostel-target-live-p cached-target))
               cached-zmx-target))
        (setq result cached
              target cached-target
              my/layout-provider-terminal-target
              target))
     (cached-zmx-target
      (let ((default-directory root))
        (setq result
              (term-sessions-open-with-frontend cached-zmx-target nil 'ghostel nil)
              my/layout-provider-terminal-target cached-zmx-target)))
     (t
      (pcase provider
        ('project-ghostel
         (unless (my/layout-project-p root)
           (user-error "%s is an ordinary folder, not a project" root))
         (let ((default-directory root))
           (setq result (ghostel-project)))
         (setq target (my/layout-ghostel-target result))
         (unless target
           (user-error "Project Ghostel terminal cannot accept input"))
         (setq my/layout-provider-terminal-target target))
        ('folder-ghostel
         (let ((default-directory root))
           (setq result (ghostel-create nil nil)))
         (setq target (my/layout-ghostel-target result))
         (unless target
           (user-error "Folder Ghostel terminal cannot accept input"))
         (setq my/layout-provider-terminal-target target))
        ('existing-zmx
         (let* ((default-directory root)
                (entry (term-sessions-read-existing-session-entry "Existing zmx session: "))
                (target (plist-put (copy-sequence entry) :type 'zmx)))
           (my/layout-validate-target-root target root nil)
           (setq result (term-sessions-open-with-frontend target nil 'ghostel nil)
                 my/layout-provider-terminal-target target)))
        ('new-zmx
         (let* ((session (plist-get entry :session))
                (name (cond
                       ((functionp session) (funcall session 'terminal root))
                       ((stringp session) session)
                       (t (my/layout-session-name root 'terminal))))
                (target (my/layout-zmx-target root name))
                (command (plist-get entry :command))
                (default-directory root))
           (unless (or (null command) (stringp command))
             (user-error "Terminal command must be a shell command string"))
           (setq result (term-sessions-open target command)
                 my/layout-provider-terminal-target target)))
        (_
         (user-error "Unknown terminal provider %s" provider)))))
    (when (memq provider '(existing-zmx new-zmx))
      (unless (my/layout-zmx-target-p my/layout-provider-terminal-target)
        (user-error "Terminal zmx target needs a nonempty name")))
    (unless (buffer-live-p result)
      (user-error "Terminal provider did not return a live buffer"))
    result))

(defun my/layout-agent-target (entry root force)
  "Resolve ENTRY's terminal-agent descriptor for ROOT without opening it."
  (let* ((session (plist-get entry :session))
         (literal-session-p (stringp session))
         (task-id (my/layout-task-id-for-root root))
         (cached-target (my/tab-current-property 'my/layout-agent-target))
         (cached-task-id (my/tab-current-property 'my/layout-agent-task-id))
         (cached
          (and (my/layout-zmx-target-p cached-target)
               (cond
                (literal-session-p
                 (equal (plist-get cached-target :name) session))
                ((and (not force)
                      (equal cached-task-id task-id))
                 (cond
                  ((null session) t)
                  ((functionp session) t))))
               cached-target))
         target new-p)
    (cond
     (cached
      (setq target cached))
     ((null session)
      (let ((default-directory root))
        (setq target
              (plist-put
               (copy-sequence
                (term-sessions-read-existing-session-entry "Existing coding-agent session: "))
               :type 'zmx))))
     ((functionp session)
      (let ((name (funcall session 'agent root)))
        (unless (stringp name)
          (user-error "Configured agent session function must return a string"))
        (setq target (my/layout-zmx-target root name)
              new-p t)))
     ((stringp session)
      (setq target (my/layout-zmx-target root session)
            new-p t))
     (t
      (user-error "Unsupported coding-agent session setting")))
    (when (and (my/layout-zmx-target-p cached-target)
               (not (equal cached-task-id task-id))
               (equal (plist-get cached-target :name)
                      (plist-get target :name)))
      (user-error "Agent session %s is cached for another task; use a task-distinct session"
                  (plist-get target :name)))
    (unless (my/layout-zmx-target-p target)
      (user-error "Coding-agent zmx target needs a nonempty name"))
    (my/layout-validate-target-root target root literal-session-p)
    (list :target target :new-p new-p)))

(defun my/layout-terminal-agent-buffer (entry force)
  "Resolve the required Ghostel/zmx coding-agent companion for ENTRY."
  (let* ((root (my/layout-root))
         (task-id (my/layout-task-id-for-root root))
         (cached (and (not force)
                      (equal (my/tab-current-property 'my/layout-agent-task-id)
                             task-id)
                      (my/layout-cached-companion 'agent)))
         (target-result (my/layout-agent-target entry root force))
         (target (plist-get target-result :target))
         (new-p (plist-get target-result :new-p))
         result)
    (if (and cached
             (eq (my/tab-current-property 'my/layout-agent-backend)
                 'terminal-agent)
             (my/layout-zmx-target-p target))
        (setq result cached)
      (let ((default-directory root))
        (setq result
              (if new-p
                  (term-sessions-open target (my/layout-agent-command entry root))
                (term-sessions-open-with-frontend target nil 'ghostel nil)))))
    (unless (buffer-live-p result)
      (user-error "Terminal-agent provider did not return a live buffer"))
    (setq my/layout-provider-agent-target target
          my/layout-provider-agent-backend 'terminal-agent)
    result))

(defun my/layout-native-agent-buffer (root task force)
  "Resolve a registered local-native Codex companion for ROOT with TASK."
  (let ((cached (and (not force)
                     (equal (my/tab-current-property 'my/layout-agent-task-id)
                            (plist-get task :id))
                     (my/layout-cached-companion 'agent)))
        result)
    (if (and cached
             (eq (my/tab-current-property 'my/layout-agent-backend) 'codex-native))
        (setq result cached)
      (setq result (funcall my/layout-codex-native-launcher
                            root task)))
    (unless (buffer-live-p result)
      (user-error "Native Codex launcher did not return a live buffer"))
    (setq my/layout-provider-agent-target my/layout-clear-target
          my/layout-provider-agent-backend 'codex-native)
    result))

(defun my/layout-agent-buffer (entry force)
  "Resolve ENTRY's capability-selected coding-agent companion.

TRAMP returns to the terminal-agent path before evaluating any optional local
  native capability."
  (let ((root (my/layout-root))
        result)
    (if (file-remote-p root)
        (setq result (my/layout-terminal-agent-buffer entry force))
      (let ((task (my/layout-workflow-task-for-root root)))
        (cond
         ((not my/layout-codex-native-launcher)
          (message "Native Codex launcher is not registered; using terminal-agent")
          (setq result (my/layout-terminal-agent-buffer entry force)))
         ((not (executable-find "codex"))
          (message "Local codex executable is unavailable; using terminal-agent")
          (setq result (my/layout-terminal-agent-buffer entry force)))
         (t
          (condition-case error-data
              (setq result (my/layout-native-agent-buffer root task force))
            (error
             (message "Native Codex startup failed: %s; using terminal-agent"
                      (error-message-string error-data))
             (setq result (my/layout-terminal-agent-buffer entry force))))))))
    result))

(defun my/layout-gptel-buffer (entry force)
  "Resolve ENTRY's root-bound Gptel conversation without consuming a region."
  (let* ((root (my/layout-root))
         (task-id (my/layout-task-id-for-root root))
         (cached (and (not force)
                      (equal (my/tab-current-property 'my/layout-gptel-task-id)
                             task-id)
                      (my/layout-cached-companion 'gptel)))
        result)
    (if cached
        (setq result cached)
      (let ((name (or (plist-get entry :buffer)
                      (when task-id
                        (format "*gptel:%s*"
                                (substring (secure-hash 'sha1 task-id) 0 8)))
                      (read-string "Gptel conversation: " "*gptel*"))))
        (setq result (gptel name))))
    (unless (buffer-live-p result)
      (user-error "Gptel did not return a live conversation buffer"))
    result))

(defun my/layout-repository-p (root)
  "Return non-nil when ROOT names a Git worktree or bare repository."
  (let ((default-directory root))
    (condition-case nil
        (eq 0 (process-file "git" nil nil nil "rev-parse" "--git-dir"))
      (error nil))))

(defun my/layout-magit-buffer (_entry _force)
  "Resolve the Magit status buffer for the authoritative workspace root."
  (let ((root (my/layout-root)))
    (unless (my/layout-repository-p root)
      (user-error "Workspace %s is not a Git repository; select a worktree or .bare directory" root))
    (let ((default-directory root)
          (result (magit-status-setup-buffer root)))
      (unless (buffer-live-p result)
        (user-error "Magit did not return a live status buffer"))
      result)))

(defun my/layout-resolve-companion (layout entry force root)
  "Resolve LAYOUT's companion before visible mutation, returning its buffer."
  (let ((function (plist-get entry :buffer-function))
        result)
    (when function
      (let ((default-directory root))
        (setq result
              (save-window-excursion
                (funcall function entry force))))
      (unless (buffer-live-p result)
        (user-error "Layout %s provider did not return a live buffer" layout)))
    result))

(defun my/layout-render (edit companion)
  "Render EDIT alone or with COMPANION, returning the selected edit window."
  (delete-other-windows)
  (switch-to-buffer edit)
  (let ((edit-window (selected-window)))
    (set-window-parameter edit-window 'my/layout-role 'edit)
    (when companion
      (let ((companion-window (display-buffer companion my/right-split-action)))
        (unless (window-live-p companion-window)
          (user-error "Layout companion did not open in a window"))
        (set-window-parameter companion-window 'my/layout-role 'companion)
        (unless (= (length (window-list nil 'no-minibuf)) 2)
          (user-error "Layout renderer did not produce exactly two windows"))))
    (select-window edit-window)
    edit-window))

(defun my/layout-commit (layout root initial-root-p edit companion)
  "Commit successful LAYOUT runtime state after its windows are rendered."
  (when initial-root-p
    (my/tab-set-current-property 'my/workspace-root root))
  (my/tab-set-current-property 'my/layout-edit-buffer edit)
  (when companion
    (let* ((cache (copy-alist (my/tab-current-property 'my/layout-companion-buffers)))
           (updated-cache (assq-delete-all layout cache)))
      (push (cons layout companion) updated-cache)
      (my/tab-set-current-property 'my/layout-companion-buffers updated-cache)))
  (cond
   ((eq my/layout-provider-terminal-target my/layout-clear-target)
    (my/tab-set-current-property 'my/layout-terminal-target nil))
   (my/layout-provider-terminal-target
    (my/tab-set-current-property 'my/layout-terminal-target
                                 my/layout-provider-terminal-target)))
  (cond
   ((eq my/layout-provider-agent-target my/layout-clear-target)
    (my/tab-set-current-property 'my/layout-agent-target nil))
   (my/layout-provider-agent-target
    (my/tab-set-current-property 'my/layout-agent-target
                                 my/layout-provider-agent-target)))
  (when my/layout-provider-agent-backend
    (my/tab-set-current-property 'my/layout-agent-backend
                                 my/layout-provider-agent-backend))
  (when (eq layout 'agent)
    (my/tab-set-current-property 'my/layout-agent-task-id
                                 (my/layout-task-id-for-root root)))
  (when (eq layout 'gptel)
    (my/tab-set-current-property 'my/layout-gptel-task-id
                                 (my/layout-task-id-for-root root)))
  (when (and (listp my/layout-provider-terminal-target)
             (pcase (plist-get my/layout-provider-terminal-target :type)
               ('zmx (plist-get my/layout-provider-terminal-target :name))
               ('ghostel (my/ghostel-target-live-p
                           my/layout-provider-terminal-target))))
    (my/send-text-save-last-target my/layout-provider-terminal-target))
  (when (and (listp my/layout-provider-agent-target)
             (plist-get my/layout-provider-agent-target :name)
             (eq (plist-get my/layout-provider-agent-target :type) 'zmx))
    (my/send-text-save-last-target my/layout-provider-agent-target)))

(defun my/layout-apply (layout &optional force)
  "Apply named LAYOUT deterministically, with FORCE reselection when non-nil."
  (interactive (list (intern (completing-read "Layout: "
                                               (mapcar #'symbol-name
                                                       (mapcar #'car my/window-layouts))
                                               nil t))
                     current-prefix-arg))
  (let* ((entry (my/layout-entry layout))
         (tabs (copy-tree (tab-bar-tabs)))
         (windows (current-window-configuration))
         (stored-root (my/tab-current-property 'my/workspace-root))
         (root (or stored-root (my/layout-root)))
         (initial-root-p (null stored-root))
         (my/layout-provider-terminal-target nil)
         (my/layout-provider-agent-target nil)
         (my/layout-provider-agent-backend nil)
         edit companion)
    (condition-case error-data
        (progn
          (setq edit (my/layout-edit-buffer root)
                companion (my/layout-resolve-companion layout entry force root))
          (my/layout-render edit companion)
          (my/layout-commit layout root initial-root-p edit companion))
      (t
       (set-window-configuration windows)
       (tab-bar-tabs-set tabs)
       (signal (car error-data) (cdr error-data))))))

(defun my/layout-select (&optional force)
  "Prompt for a catalog layout and apply it, optionally forcing reselection."
  (interactive "P")
  (let* ((choices (mapcar (lambda (entry)
                            (cons (format "%s: %s"
                                          (plist-get (cdr entry) :key)
                                          (plist-get (cdr entry) :label))
                                  (car entry)))
                          my/window-layouts))
         (choice (completing-read "Workspace layout: " choices nil t)))
    (my/layout-apply (alist-get choice choices nil nil #'string=) force)))

(defun my/workspace-select (&optional directory rebind)
  "Select DIRECTORY's workspace tab, or REBIND the current tab when requested.

New workspace tabs receive a Dired edit buffer.  Prefix rebinding prepares
Dired before it changes root or clears layout-only runtime state."
  (interactive (list nil current-prefix-arg))
  (let* ((window (selected-window))
         (role (window-parameter window 'my/layout-role))
         (source-buffer
          (if (eq role 'companion)
              (let ((edit (my/tab-current-property 'my/layout-edit-buffer)))
                (unless (buffer-live-p edit)
                  (user-error "Workspace companion has no usable edit buffer"))
                edit)
            (window-buffer window)))
         (default-directory (with-current-buffer source-buffer default-directory))
         (directory (or directory (project-prompt-project-dir "Workspace: " nil nil)))
         (root (my/workspace-normalize-root directory))
         (tabs (copy-tree (tab-bar-tabs)))
         (windows (current-window-configuration))
         (existing-index (my/workspace-tab-index root))
         prepared)
    (condition-case error-data
        (progn
          (cond
           ((and (not rebind) existing-index)
            (tab-bar-select-tab existing-index))
           (rebind
            (let ((current-index
                   (cl-loop for tab in (tab-bar-tabs)
                            for index from 1
                            when (eq (car tab) 'current-tab)
                            return index)))
              (when (and existing-index
                         (not (= existing-index current-index)))
                (user-error "Workspace %s is already owned by another tab" root)))
            (setq prepared (dired-noselect root))
            (my/tab-set-current-property 'my/workspace-root root)
            (my/tab-set-current-property 'my/layout-edit-buffer prepared)
            (my/tab-set-current-property 'my/work-task-id nil)
            (my/tab-set-current-property 'my/layout-companion-buffers nil)
            (my/tab-set-current-property 'my/layout-terminal-target nil)
            (my/tab-set-current-property 'my/layout-agent-target nil)
            (my/tab-set-current-property 'my/layout-agent-backend nil)
            (my/tab-set-current-property 'my/layout-agent-task-id nil)
            (my/tab-set-current-property 'my/layout-gptel-task-id nil)
            (my/tab-set-current-property 'my/send-text-last-target nil)
            (my/layout-render prepared nil))
           (t
            (setq prepared (dired-noselect root))
            (my/workspace-select-or-create-tab root)
            (tab-bar-rename-tab (file-name-nondirectory (directory-file-name root)))
            (my/tab-set-current-property 'my/layout-edit-buffer prepared)
            (my/layout-render prepared nil))))
      (t
       (set-window-configuration windows)
       (tab-bar-tabs-set tabs)
       (signal (car error-data) (cdr error-data))))))

(defun my/work-codex (&optional force)
  "Open the capability-selected coding-agent layout for the current workspace."
  (interactive "P")
  (my/layout-apply 'agent force))

(provide 'my-window-layouts)

;;; my-window-layouts.el ends here
