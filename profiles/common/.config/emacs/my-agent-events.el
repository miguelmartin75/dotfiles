;;; my-agent-events.el --- Bounded local agent event presentation -*- lexical-binding: t; -*-

;;; Commentary:

;; This module accepts one JSON event at a time through its public entry point.
;; It deliberately owns presentation only: agent events never update Org state,
;; append journal entries, start agents, or refresh files.

;;; Code:

(require 'json)
(require 'seq)
(require 'subr-x)
(require 'tab-bar)
(require 'my-workflow)

(defgroup my/agent-events nil
  "Bounded lifecycle events reported by local coding agents."
  :group 'applications)

(defconst my/agent-events-max-raw-bytes 65536
  "Maximum UTF-8 byte size accepted for one raw event JSON document.")

(defconst my/agent-events-max-provider-bytes 64
  "Maximum UTF-8 byte size for a provider name.")

(defconst my/agent-events-max-session-id-bytes 256
  "Maximum UTF-8 byte size for a provider session ID.")

(defconst my/agent-events-max-event-id-bytes 256
  "Maximum UTF-8 byte size for a provider event ID.")

(defconst my/agent-events-max-timestamp-bytes 128
  "Maximum UTF-8 byte size for an event timestamp.")

(defconst my/agent-events-max-cwd-bytes 4096
  "Maximum UTF-8 byte size for a local event working directory.")

(defconst my/agent-events-max-workspace-root-bytes 4096
  "Maximum UTF-8 byte size for a supplied workspace root.")

(defconst my/agent-events-max-task-id-bytes 256
  "Maximum UTF-8 byte size for an Org task ID.")

(defconst my/agent-events-max-title-bytes 256
  "Maximum UTF-8 byte size for an event title.")

(defconst my/agent-events-max-body-bytes 8192
  "Maximum UTF-8 byte size for an event body.")

(defconst my/agent-events-max-path-count 128
  "Maximum changed paths accepted from one event.")

(defconst my/agent-events-max-path-bytes 1024
  "Maximum UTF-8 byte size for one changed path.")

(defconst my/agent-events-required-keys
  '("schema_version" "provider" "session_id" "event_id" "kind" "timestamp"
    "cwd" "title" "body" "changed_paths")
  "JSON keys which every v1 agent event must supply.")

(defconst my/agent-events-optional-keys
  '("task_id" "workspace_root" "sequence" "observed_mtime" "observed_size")
  "JSON keys accepted in addition to the required v1 event keys.")

(defconst my/agent-events-kinds
  '("progress" "attention" "done" "error" "files-changed")
  "Provider-neutral lifecycle kinds accepted by the event API.")

(defconst my/agent-events-buffer-name "*Agent Events*"
  "Name of the persistent local agent event presentation buffer.")

(defvar my/agent-events-seen-ids (make-hash-table :test 'equal)
  "Accepted event identity triples for the current Emacs process.")

(defvar my/agent-events-mode-line-status nil
  "Small status string shown in `global-mode-string' after an agent event.")

(unless (member 'my/agent-events-mode-line-status global-mode-string)
  (setq global-mode-string
        (append global-mode-string '(my/agent-events-mode-line-status))))

(defvar my/agent-events-json-null (make-symbol "my/agent-events-json-null")
  "Sentinel used to reject JSON null where a concrete value is required.")

(defvar my/agent-events-json-false (make-symbol "my/agent-events-json-false")
  "Sentinel used to reject JSON false where a concrete value is required.")

(defvar my/agent-events-missing (make-symbol "my/agent-events-missing")
  "Sentinel distinguishing a missing JSON member from a JSON null member.")

(defvar my/agent-events-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "l" #'my/agent-events-log-selected-done)
    map)
  "Keymap for `my/agent-events-mode'.")

(define-derived-mode my/agent-events-mode special-mode "Agent-Events"
  "Major mode for local agent lifecycle events.")

(defun my/agent-events-string-bytes (value)
  "Return VALUE's UTF-8 byte length."
  (string-bytes (encode-coding-string value 'utf-8)))

(defun my/agent-events-validate-string (value description maximum &optional allow-empty)
  "Return VALUE after checking DESCRIPTION's type, bounds, and line safety.

When ALLOW-EMPTY is non-nil, an empty string is accepted.  Event body text may
be multiline, so callers needing that behavior validate its NUL safety below."
  (unless (and (stringp value)
               (or allow-empty (not (string-empty-p value)))
               (not (string-match-p "\0" value))
               (<= (my/agent-events-string-bytes value) maximum))
    (user-error "%s has an invalid type or size" description))
  value)

(defun my/agent-events-validate-identifier (value description maximum)
  "Return VALUE when DESCRIPTION is a bounded single-line identifier string."
  (my/agent-events-validate-string value description maximum)
  (when (string-match-p "[\r\n]" value)
    (user-error "%s must be one line" description))
  value)

(defun my/agent-events-validate-directory (value description maximum)
  "Return VALUE when it is a bounded local absolute directory identity string."
  (my/agent-events-validate-identifier value description maximum)
  (unless (and (file-name-absolute-p value)
               (not (file-remote-p value))
               (not (string-prefix-p "~" value))
               (not (member ".." (split-string value "/" t))))
    (user-error "%s must be a local absolute path without parent traversal"
                description))
  value)

(defun my/agent-events-validate-path (path)
  "Return PATH when it is a bounded relative changed path."
  (my/agent-events-validate-identifier
   path "Changed path" my/agent-events-max-path-bytes)
  (unless (and (not (file-name-absolute-p path))
               (not (file-remote-p path))
               (not (string-prefix-p "~" path))
               (not (string-prefix-p "\\\\" path))
               (not (string-match-p "\\`[[:alpha:]]:[/\\\\]" path))
               (not (member ".." (split-string path "[/\\\\]+" t))))
    (user-error "Changed path must be relative and free of parent traversal"))
  path)

(defun my/agent-events-validate-nonnegative-integer (value description)
  "Return VALUE when DESCRIPTION is a JSON nonnegative integer."
  (unless (and (integerp value) (>= value 0))
    (user-error "%s must be a nonnegative integer" description))
  value)

(defun my/agent-events-validate-nonnegative-number (value description)
  "Return VALUE when DESCRIPTION is a JSON nonnegative number."
  (unless (and (numberp value) (>= value 0))
    (user-error "%s must be a nonnegative number" description))
  value)

(defun my/agent-events-member (object key)
  "Return OBJECT's string KEY value, or the missing sentinel."
  (gethash key object my/agent-events-missing))

(defun my/agent-events-validate-object-keys (object)
  "Reject OBJECT keys outside the frozen v1 agent-event schema."
  (unless (hash-table-p object)
    (user-error "Agent event must be a JSON object"))
  (maphash
   (lambda (key value)
     (unless (and (stringp key)
                  (member key
                          (append my/agent-events-required-keys
                                  my/agent-events-optional-keys)))
       (user-error "Agent event has an unknown key"))
     (when (memq value (list my/agent-events-json-null
                             my/agent-events-json-false))
       (user-error "Agent event contains an invalid JSON value")))
   object)
  (dolist (key my/agent-events-required-keys)
    (when (eq (my/agent-events-member object key) my/agent-events-missing)
      (user-error "Agent event is missing %s" key))))

(defun my/agent-events-parse (raw)
  "Validate RAW JSON and return its normalized event plist without side effects."
  (unless (and (stringp raw)
               (<= (my/agent-events-string-bytes raw) my/agent-events-max-raw-bytes))
    (user-error "Agent event payload has an invalid type or size"))
  (let ((object (json-parse-string raw
                                   :object-type 'hash-table
                                   :array-type 'list
                                   :null-object my/agent-events-json-null
                                   :false-object my/agent-events-json-false)))
    (my/agent-events-validate-object-keys object)
    (let* ((schema-version (my/agent-events-member object "schema_version"))
           (provider (my/agent-events-validate-identifier
                      (my/agent-events-member object "provider")
                      "Provider" my/agent-events-max-provider-bytes))
           (session-id (my/agent-events-validate-identifier
                        (my/agent-events-member object "session_id")
                        "Session ID" my/agent-events-max-session-id-bytes))
           (event-id (my/agent-events-validate-identifier
                      (my/agent-events-member object "event_id")
                      "Event ID" my/agent-events-max-event-id-bytes))
           (kind (my/agent-events-validate-identifier
                  (my/agent-events-member object "kind") "Kind" 32))
           (timestamp (my/agent-events-validate-identifier
                       (my/agent-events-member object "timestamp")
                       "Timestamp" my/agent-events-max-timestamp-bytes))
           (cwd (my/agent-events-validate-directory
                 (my/agent-events-member object "cwd")
                 "Working directory" my/agent-events-max-cwd-bytes))
           (title (my/agent-events-validate-string
                   (my/agent-events-member object "title")
                   "Title" my/agent-events-max-title-bytes t))
           (body (my/agent-events-validate-string
                  (my/agent-events-member object "body")
                  "Body" my/agent-events-max-body-bytes t))
           (changed-paths (my/agent-events-member object "changed_paths"))
           (workspace-root (my/agent-events-member object "workspace_root"))
           (task-id (my/agent-events-member object "task_id"))
           (sequence (my/agent-events-member object "sequence"))
           (observed-mtime (my/agent-events-member object "observed_mtime"))
           (observed-size (my/agent-events-member object "observed_size"))
           (derived-root (my/workspace-normalize-root cwd)))
      (unless (and (integerp schema-version) (= schema-version 1))
        (user-error "Unsupported agent event schema version"))
      (unless (member kind my/agent-events-kinds)
        (user-error "Unsupported agent event kind"))
      (when (and (not (equal kind "files-changed"))
                 (or (not (eq sequence my/agent-events-missing))
                     (not (eq observed-mtime my/agent-events-missing))
                     (not (eq observed-size my/agent-events-missing))))
        (user-error "File observation fields require a files-changed event"))
      (unless (listp changed-paths)
        (user-error "Changed paths must be a JSON array"))
      (when (> (length changed-paths) my/agent-events-max-path-count)
        (user-error "Agent event has too many changed paths"))
      (setq changed-paths (mapcar #'my/agent-events-validate-path changed-paths))
      (unless (eq workspace-root my/agent-events-missing)
        (my/agent-events-validate-directory workspace-root "Workspace root"
                                            my/agent-events-max-workspace-root-bytes)
        (unless (and (equal workspace-root (my/workspace-normalize-root workspace-root))
                     (equal workspace-root derived-root))
          (user-error "Workspace root is not normalized for this working directory")))
      (unless (eq task-id my/agent-events-missing)
        (my/agent-events-validate-identifier task-id "Task ID"
                                              my/agent-events-max-task-id-bytes))
      (unless (eq sequence my/agent-events-missing)
        (my/agent-events-validate-nonnegative-integer sequence "Sequence"))
      (unless (eq observed-mtime my/agent-events-missing)
        (my/agent-events-validate-nonnegative-number observed-mtime
                                                      "Observed modification time"))
      (unless (eq observed-size my/agent-events-missing)
        (my/agent-events-validate-nonnegative-integer observed-size "Observed size"))
      (list :schema-version schema-version
            :provider provider
            :session-id session-id
            :event-id event-id
            :kind kind
            :timestamp timestamp
            :cwd cwd
            :workspace-root derived-root
            :title title
            :body body
            :changed-paths changed-paths
            :task-id (unless (eq task-id my/agent-events-missing) task-id)
            :sequence (unless (eq sequence my/agent-events-missing) sequence)
            :observed-mtime
            (unless (eq observed-mtime my/agent-events-missing) observed-mtime)
            :observed-size
            (unless (eq observed-size my/agent-events-missing) observed-size)))))

(defun my/agent-events-tabs-for-root (root)
  "Return every existing tab whose exact root property is ROOT."
  (let (result)
    (dolist (tab (tab-bar-tabs))
      (when (equal (alist-get 'my/workspace-root (cdr tab)) root)
        (push tab result)))
    (nreverse result)))

(defun my/agent-events-route (event)
  "Return EVENT annotated with its verified task routing state.

This function never creates or rebinds tabs.  A task-qualified event can stay
unbound when no matching bound tab exists, while concrete task/root or tab/task
disagreement is rejected."
  (let* ((root (plist-get event :workspace-root))
         (task-id (plist-get event :task-id))
         (tabs (my/agent-events-tabs-for-root root))
         (route (if (> (length tabs) 1) 'ambiguous 'unbound))
         task)
    (when task-id
      (setq task (my/workflow-find-task task-id))
      (unless task
        (user-error "Agent event references an unknown task"))
      (unless (equal (plist-get task :root) root)
        (user-error "Agent event task, workspace root, and working directory disagree")))
    (cond
     ((> (length tabs) 1)
      (setq route 'ambiguous))
     (task
      (let ((bound-task-id (alist-get 'my/work-task-id (cdr (car tabs)))))
        (cond
         ((null (car tabs))
          (setq route 'unbound))
         ((null bound-task-id)
          (setq route 'unbound))
         ((not (equal bound-task-id task-id))
         (user-error "Agent event task disagrees with the workspace tab"))
         (t
          (setq route 'bound)))))
     ((car tabs)
      (let ((bound-task-id (alist-get 'my/work-task-id (cdr (car tabs)))))
        (when bound-task-id
          (setq task (my/workflow-find-task bound-task-id))
          (when task
            (unless (equal (plist-get task :root) root)
              (user-error "Workspace tab task and root disagree"))
            (setq route 'bound)))))
     (t
      (setq route 'unbound)))
    (plist-put event :route route)
    (plist-put event :task task)
    event))

(defun my/agent-events-identity (event)
  "Return EVENT's exact provider, session, and event-ID deduplication key."
  (list (plist-get event :provider)
        (plist-get event :session-id)
        (plist-get event :event-id)))

(defun my/agent-events-route-label (event)
  "Return a concise visible routing label for EVENT."
  (pcase (plist-get event :route)
    ('bound (format "bound:%s" (plist-get (plist-get event :task) :id)))
    ('ambiguous "ambiguous")
    (_ "unbound")))

(defun my/agent-events-render (event)
  "Append accepted EVENT to its presentation buffer and return that buffer."
  (let ((buffer (get-buffer-create my/agent-events-buffer-name))
        (title (replace-regexp-in-string "[\r\n]+" " " (plist-get event :title)))
        (body (plist-get event :body)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t)
            (start (point-max)))
        (unless (derived-mode-p 'my/agent-events-mode)
          (my/agent-events-mode))
        (goto-char (point-max))
        (insert (format "%s [%s] %s/%s %s (%s)\n"
                        (plist-get event :timestamp)
                        (plist-get event :kind)
                        (plist-get event :provider)
                        (plist-get event :session-id)
                        title
                        (my/agent-events-route-label event)))
        (when (not (string-empty-p body))
          (insert body)
          (unless (bolp)
            (newline)))
        (dolist (path (plist-get event :changed-paths))
          (insert "  " path "\n"))
        (add-text-properties start (point)
                             (list 'my/agent-event event))))
    buffer))

(defun my/agent-events-update-mode-line (event)
  "Update the lightweight global mode-line state for EVENT."
  (setq my/agent-events-mode-line-status
        (format " Agent:%s" (plist-get event :kind)))
  (force-mode-line-update t))

(defun my/agent-events-display (buffer)
  "Show BUFFER without selecting its window or frame."
  (display-buffer
   buffer
   '((display-buffer-reuse-window display-buffer-pop-up-window)
     (inhibit-same-window . t))))

(defun my/agent-events-present (event)
  "Present accepted EVENT without any workflow mutation."
  (let ((buffer (my/agent-events-render event))
        (kind (plist-get event :kind)))
    (my/agent-events-update-mode-line event)
    (when (member kind '("done" "error"))
      (message "Agent %s: %s" kind (plist-get event :title)))
    (when (member kind '("attention" "error"))
      (my/agent-events-display buffer))
    event))

(defun my/agent-events-process (raw)
  "Validate, route, deduplicate, and present one deferred RAW JSON event."
  (condition-case err
      (let* ((event (my/agent-events-route (my/agent-events-parse raw)))
             (identity (my/agent-events-identity event)))
        (unless (gethash identity my/agent-events-seen-ids)
          (puthash identity t my/agent-events-seen-ids)
          (my/agent-events-present event)))
    (error
     (message "Rejected agent event: %s" (error-message-string err))
     nil)))

(defun my/agent-events-ingest (raw)
  "Schedule one RAW v1 JSON event for deferred local processing.

The fixed `emacsclient' expression supplies RAW only as inert data.  Parsing,
routing, and presentation run on the next Emacs timer turn so server evaluation
stays short."
  (unless (and (stringp raw)
               (<= (my/agent-events-string-bytes raw) my/agent-events-max-raw-bytes))
    (user-error "Agent event payload has an invalid type or size"))
  (run-at-time 0 nil #'my/agent-events-process raw))

(defun my/agent-events-current-event ()
  "Return the event stored on the current event-buffer line, or signal an error."
  (or (get-text-property (line-beginning-position) 'my/agent-event)
      (user-error "No agent event is selected")))

(defun my/agent-events-done-summary (event)
  "Return EVENT's concise one-line work-log prompt default."
  (let ((summary
         (string-join
          (seq-filter
           (lambda (part) (not (string-empty-p part)))
           (list (replace-regexp-in-string "[\r\n[:space:]]+" " "
                                           (plist-get event :title))
                 (replace-regexp-in-string "[\r\n[:space:]]+" " "
                                           (plist-get event :body))))
          ": ")))
    (truncate-string-to-width summary 240 nil nil "...")))

(defun my/agent-events-log-selected-done ()
  "Prompt to log the selected bound done event without changing tab focus."
  (interactive)
  (let ((event (my/agent-events-current-event)))
    (unless (equal (plist-get event :kind) "done")
      (user-error "Only done events can prefill a work log"))
    (unless (and (eq (plist-get event :route) 'bound)
                 (plist-get event :task))
      (user-error "The selected done event is not bound to a work task"))
    (my/work-log 'done
                 (read-string "Work log: " (my/agent-events-done-summary event))
                 (plist-get event :task))))

(provide 'my-agent-events)

;;; my-agent-events.el ends here
