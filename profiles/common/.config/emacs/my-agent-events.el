;;; my-agent-events.el --- Bounded local agent event presentation -*- lexical-binding: t; -*-

;;; Commentary:

;; This module accepts bounded local and explicitly configured remote agent
;; events.  Remote transport is deliberately independent from TRAMP: it uses a
;; narrow reverse Unix-socket forward, while TRAMP remains the file transport.

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)
(require 'tab-bar)
(require 'tramp)
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

(defconst my/agent-events-max-relay-name-bytes 48
  "Maximum UTF-8 byte size for one conservative relay name.")

(defconst my/agent-events-max-unix-socket-bytes 100
  "Safe maximum UTF-8 byte size for a local or remote AF_UNIX socket path.

macOS permits about 104 bytes including its terminating NUL, so this lower
limit leaves room for platform variation.")

(defconst my/agent-events-max-sequence 9223372036854775807
  "Largest accepted provider file-event sequence number.")

(defconst my/agent-events-listener-deadline 2
  "Total seconds one relay client may keep its connection open.")

(defconst my/agent-events-listener-max-clients 8
  "Maximum concurrent relay client connections.")

(defconst my/agent-events-listener-max-pending 64
  "Maximum accepted relay frames waiting for deferred presentation.")

(defconst my/agent-events-relay-maintenance-timeout 5
  "Maximum seconds a local SSH maintenance command may run.")

(defconst my/agent-events-relay-termination-timeout 1
  "Maximum seconds spent reaping a terminated local SSH process.")

(defconst my/agent-events-relay-tunnel-readiness-timeout 1
  "Maximum seconds spent waiting for an SSH tunnel's initial failure signal.")

(defconst my/agent-events-relay-allowed-ssh-option-names
  '("globalknownhostsfile" "identitiesonly" "identityfile" "kbdinteractiveauthentication"
    "loglevel" "passwordauthentication" "port" "preferredauthentications"
    "pubkeyauthentication" "serveralivecountmax" "serveraliveinterval"
    "stricthostkeychecking" "user" "userknownhostsfile")
  "Reviewed `ssh -o' keys which cannot add local execution or forwarding.")

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
  "Accepted source/provider/session/event identities for this Emacs process.")

(defvar my/agent-events-latest-sequences (make-hash-table :test 'equal)
  "Latest accepted sequence for each source/provider/session/path tuple.")

(defvar my/agent-events-relay-states (make-hash-table :test 'equal)
  "Runtime state keyed by configured relay name.")

(defvar my/agent-events-relay-generation 0
  "Monotonic generation number assigned to each newly started relay.")

(defcustom my/agent-events-relay-directory
  (expand-file-name "agent-events/" user-emacs-directory)
  "Private local directory containing relay listener sockets.

The directory is trusted only after it is confirmed to be a non-symlink owned
by this Emacs user's UID with mode exactly 0700.  This reduces races with other
local users through race-resistant identity checks, but cannot make pathname
operations falsely race-free against the same UID."
  :type 'directory)

(defcustom my/agent-events-relays nil
  "Explicit remote relay configurations.

Each entry is a plist with :name, :workspace-root, :ssh-destination,
:ssh-options, and :remote-socket.  :workspace-root is the exact normalized
TRAMP root.  SSH destination and options are reviewed configuration values;
they are never inferred from its TRAMP prefix.  :remote-socket is an absolute
POSIX socket path whose direct parent is the remote private directory."
  :type '(repeat plist))

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
  "Return PATH when it is a canonical bounded POSIX relative changed path."
  (my/agent-events-validate-identifier
   path "Changed path" my/agent-events-max-path-bytes)
  (unless (and (not (string-prefix-p "/" path))
               (not (file-remote-p path))
               (not (string-match-p "[\\\\~]" path))
               (not (string-match-p "\\`[[:alpha:]]:" path))
               (not (string-suffix-p "/" path))
               (not (member "" (split-string path "/" nil)))
               (not (member "." (split-string path "/" nil)))
               (not (member ".." (split-string path "/" nil))))
    (user-error "Changed path must be canonical POSIX-relative"))
  path)

(defun my/agent-events-validate-nonnegative-integer (value description &optional maximum)
  "Return VALUE when DESCRIPTION is a JSON nonnegative integer."
  (unless (and (integerp value) (>= value 0)
               (or (null maximum) (<= value maximum)))
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

(defun my/agent-events-remote-directory-identity (value description maximum)
  "Return VALUE as one canonical remote directory identity.

One trailing slash is accepted and removed, except for the POSIX root
directory.  This lets a relay's configured root and an event's root compare
as directory identities before either is mapped through TRAMP."
  (my/agent-events-validate-identifier value description maximum)
  (when (and (not (equal value "/")) (string-suffix-p "//" value))
    (user-error "%s must not have multiple trailing slashes" description))
  (let ((result (if (equal value "/") value (directory-file-name value))))
    (my/agent-events-validate-remote-localname result description maximum)
    result))

(defun my/agent-events-parse-schema (raw &optional relay)
  "Validate RAW JSON and return its normalized event plist for optional RELAY.

When RELAY is nil, validate a local event.  Otherwise RELAY is trusted
configuration which supplies the sole TRAMP prefix after remote localname
roots and working-directory containment have been checked."
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
           (cwd (my/agent-events-member object "cwd"))
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
           workspace-root-identity
           derived-root
           source
           remote)
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
      (unless (eq task-id my/agent-events-missing)
        (my/agent-events-validate-identifier task-id "Task ID"
                                              my/agent-events-max-task-id-bytes))
      (unless (eq sequence my/agent-events-missing)
        (my/agent-events-validate-nonnegative-integer
         sequence "Sequence" my/agent-events-max-sequence)
        (when (equal session-id "unknown")
          (user-error "Sequence requires a provider session ID")))
      (unless (eq observed-mtime my/agent-events-missing)
        (my/agent-events-validate-nonnegative-number observed-mtime
                                                      "Observed modification time"))
      (unless (eq observed-size my/agent-events-missing)
        (my/agent-events-validate-nonnegative-integer observed-size "Observed size"))
      (when (and (or (not (eq observed-mtime my/agent-events-missing))
                     (not (eq observed-size my/agent-events-missing)))
                 (/= (length changed-paths) 1))
        (user-error "Observed file metadata requires exactly one changed path"))
      (if relay
          (let ((local-root
                 (my/agent-events-remote-directory-identity
                  (plist-get relay :local-root) "Configured relay root"
                  my/agent-events-max-workspace-root-bytes)))
            (setq cwd (my/agent-events-remote-directory-identity
                       cwd "Working directory" my/agent-events-max-cwd-bytes))
            (unless (my/agent-events-remote-path-contained-p local-root cwd)
              (user-error "Working directory is outside the configured relay root"))
            (unless (eq workspace-root my/agent-events-missing)
              (setq workspace-root-identity
                    (my/agent-events-remote-directory-identity
                     workspace-root "Workspace root"
                     my/agent-events-max-workspace-root-bytes))
              (unless (equal workspace-root-identity local-root)
                (user-error "Workspace root does not match the configured relay root")))
            (setq cwd (concat (plist-get relay :tramp-prefix) cwd)
                  derived-root (plist-get relay :workspace-root)
                  source (plist-get relay :workspace-root)
                  remote t))
        (setq cwd (my/agent-events-validate-directory
                   cwd "Working directory" my/agent-events-max-cwd-bytes)
              derived-root (my/workspace-normalize-root cwd))
        (unless (eq workspace-root my/agent-events-missing)
          (my/agent-events-validate-directory workspace-root "Workspace root"
                                              my/agent-events-max-workspace-root-bytes)
          (unless (and (equal workspace-root (my/workspace-normalize-root workspace-root))
                       (equal workspace-root derived-root))
            (user-error "Workspace root is not normalized for this working directory"))))
      (append
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
             (unless (eq observed-size my/agent-events-missing) observed-size))
       (when remote
         (list :source source :remote t :relay (plist-get relay :name)))))))

(defun my/agent-events-validate-remote-localname (value description maximum)
  "Return VALUE when it is one canonical absolute POSIX remote localname."
  (my/agent-events-validate-identifier value description maximum)
  (unless (and (string-prefix-p "/" value)
               (not (file-remote-p value))
               (not (string-match-p "[\\\\~]" value))
               (not (string-match-p "\\`/[[:alpha:]]:" value))
               (or (equal value "/")
                   (and (not (string-match-p "//" value))
                        (not (string-match-p "/\\(?:\\.\\.?\\)\\(?:/\\|\\'\\)" value))
                        (not (member "" (split-string (substring value 1) "/" nil))))))
    (user-error "%s must be a canonical absolute POSIX remote path" description))
  value)

(defun my/agent-events-remote-path-contained-p (root path)
  "Return non-nil when absolute POSIX PATH is component-contained by ROOT."
  (let ((directory (file-name-as-directory root)))
    (or (equal path root)
        (string-prefix-p directory (file-name-as-directory path)))))

(defun my/agent-events-parse (raw)
  "Validate local RAW JSON and return its normalized event plist."
  (my/agent-events-parse-schema raw))

(defun my/agent-events-parse-remote (raw relay)
  "Validate remote RAW JSON against trusted RELAY and map it through TRAMP."
  (my/agent-events-parse-schema raw relay))

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
  "Return EVENT's source/provider/session/event-ID deduplication key."
  (list (or (plist-get event :source) 'local)
        (plist-get event :provider)
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
        (when-let* ((diagnostic (plist-get event :diagnostic)))
          (insert "  diagnostic: " diagnostic "\n"))
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

(defun my/agent-events-sequence-key (event path)
  "Return EVENT's trusted per-path sequence key for canonical PATH."
  (list (or (plist-get event :source) 'local)
        (plist-get event :provider)
        (plist-get event :session-id)
        (plist-get event :workspace-root)
        path))

(defun my/agent-events-accept-sequence-p (event)
  "Return EVENT copied with only advancing sequence paths, or nil.

Events without a sequence retain event-ID deduplication only.  A sequenced
event with session ID `unknown' is invalid because it would share a fallback
sequence space.  Stale paths are removed independently, and only accepted
paths advance their stored sequence values.
"
  (let ((sequence (plist-get event :sequence))
        (result (copy-sequence event))
        paths)
    (if (null sequence)
        result
      (when (equal (plist-get event :session-id) "unknown")
        (user-error "Sequence requires a provider session ID"))
      (dolist (path (plist-get event :changed-paths))
        (let ((latest (gethash (my/agent-events-sequence-key event path)
                               my/agent-events-latest-sequences)))
          (when (or (null latest) (> sequence latest))
            (push path paths))))
      (setq paths (nreverse paths))
      (when paths
        (plist-put result :changed-paths paths)
        (dolist (path paths)
          (puthash (my/agent-events-sequence-key result path) sequence
                   my/agent-events-latest-sequences))
        result))))

(defun my/agent-events-remote-file-name (event path)
  "Return trusted TRAMP filename for EVENT's canonical remote PATH."
  (let ((state (gethash (plist-get event :relay) my/agent-events-relay-states)))
    (unless state
      (user-error "Remote relay state is unavailable"))
    (let ((relay (plist-get state :config)))
      (concat (plist-get relay :tramp-prefix)
              (concat (file-name-as-directory (plist-get relay :local-root)) path)))))

(defun my/agent-events-refresh-attention (event)
  "Return EVENT transformed into a visible non-destructive refresh conflict."
  (let ((result (copy-sequence event)))
    (plist-put result :kind "attention")
    (plist-put result :title "Remote change needs attention")
    (plist-put result :body
               "A changed remote file could not be refreshed safely; no buffer was reverted.")
    result))

(defun my/agent-events-remote-observation-diagnostic (event attributes)
  "Return a concise metadata mismatch diagnostic for EVENT and ATTRIBUTES.

This only records a provider observation mismatch.  It must not decide whether
a visited remote buffer is current or may be refreshed.
"
  (let (differences)
    (when (and (plist-get event :observed-mtime)
               (not (= (plist-get event :observed-mtime)
                       (float-time (file-attribute-modification-time attributes)))))
      (push "mtime" differences))
    (when (and (plist-get event :observed-size)
               (/= (plist-get event :observed-size)
                   (file-attribute-size attributes)))
      (push "size" differences))
    (when differences
      (format "Remote metadata differs: %s"
              (string-join (nreverse differences) ", ")))))

(defun my/agent-events-refresh-remote (event)
  "Refresh clean visited files for one accepted remote EVENT, when safe.

Unvisited files are only recorded by the event buffer.  Provider observed
mtime and size remain diagnostics: current TRAMP attributes alone control the
refresh decision.
"
  (let ((result (copy-sequence event)))
    (when (and (plist-get event :remote)
               (eq (plist-get event :route) 'bound)
               (equal (plist-get event :kind) "files-changed"))
      (dolist (path (plist-get event :changed-paths))
        (let* ((file (my/agent-events-remote-file-name event path))
               (buffer (get-file-buffer file)))
          (when buffer
            (if (buffer-modified-p buffer)
                (setq result (my/agent-events-refresh-attention result))
              (condition-case nil
                  (let ((attributes (file-attributes file 'integer)))
                    (if (null attributes)
                        (setq result (my/agent-events-refresh-attention result))
                      (let ((diagnostic
                             (my/agent-events-remote-observation-diagnostic
                              result attributes)))
                        (when diagnostic
                          (plist-put result :diagnostic diagnostic))
                        (with-current-buffer buffer
                          (unless (verify-visited-file-modtime buffer)
                            (if (buffer-modified-p buffer)
                                (setq result (my/agent-events-refresh-attention result))
                              (revert-buffer t t t)))))))
                (error
                 (setq result (my/agent-events-refresh-attention result)))))))))
    result))

(defun my/agent-events-process-event (event)
  "Route, deduplicate, sequence-check, refresh, and present one parsed EVENT."
  (let* ((event (my/agent-events-route event))
         (identity (my/agent-events-identity event)))
    (unless (gethash identity my/agent-events-seen-ids)
      (setq event (my/agent-events-accept-sequence-p event))
      (when event
        (puthash identity t my/agent-events-seen-ids)
        (setq event (my/agent-events-refresh-remote event))
        (my/agent-events-present event)))))

(defun my/agent-events-process (raw)
  "Validate, route, deduplicate, and present one deferred local RAW event."
  (condition-case err
      (my/agent-events-process-event (my/agent-events-parse raw))
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

(defun my/agent-events-relay-name (value)
  "Return VALUE's stable relay-name string after validation."
  (let ((result (if (symbolp value) (symbol-name value) value)))
    (unless (and (stringp result)
                 (<= (my/agent-events-string-bytes result)
                     my/agent-events-max-relay-name-bytes)
                 (string-match-p "\\`[[:alnum:]_-]+\\'" result))
      (user-error "Relay name must contain only letters, digits, hyphen, and underscore"))
    result))

(defun my/agent-events-validate-unix-socket-path (path description)
  "Return PATH when DESCRIPTION is a safe-sized absolute AF_UNIX path.

The byte limit is checked before a local listener or SSH process is created.
"
  (unless (and (stringp path)
               (file-name-absolute-p path)
               (not (file-remote-p path))
               (not (string-match-p "\0" path))
               (<= (my/agent-events-string-bytes path)
                   my/agent-events-max-unix-socket-bytes))
    (user-error "%s exceeds the safe AF_UNIX path bound" description))
  path)

(defun my/agent-events-relay-ssh-argument (value description)
  "Return configured SSH VALUE after rejecting control characters."
  (unless (and (stringp value)
               (not (string-empty-p value))
               (not (string-match-p "[\0\r\n]" value)))
    (user-error "%s must be one nonempty SSH argument" description))
  value)

(defun my/agent-events-relay-ssh-option-name (option)
  "Return OPTION's lower-case SSH `-o' key, or signal an invalid option."
  (unless (string-match "\\`\\([[:alpha:]][[:alnum:]]*\\)=" option)
    (user-error "Relay SSH -o options must use Key=Value syntax"))
  (downcase (match-string 1 option)))

(defun my/agent-events-relay-validate-ssh-option (option)
  "Return SSH `-o' OPTION only for the reviewed non-forwarding allowlist."
  (let ((name (my/agent-events-relay-ssh-option-name option)))
    (unless (member name my/agent-events-relay-allowed-ssh-option-names)
      (user-error "Relay SSH option %s is not allowlisted" name)))
  option)

(defun my/agent-events-relay-ssh-options (options)
  "Return reviewed SSH OPTIONS without forwarding or proxy escape hatches."
  (unless (listp options)
    (user-error "Relay SSH options must be a list"))
  (let ((remaining options))
    (while remaining
      (let ((option (pop remaining)))
        (my/agent-events-relay-ssh-argument option "Relay SSH option")
        (cond
         ((equal option "-o")
          (unless remaining
            (user-error "Relay SSH -o requires one Key=Value argument"))
          (my/agent-events-relay-validate-ssh-option
           (my/agent-events-relay-ssh-argument
            (pop remaining) "Relay SSH -o option")))
         ((string-prefix-p "-o" option)
          (my/agent-events-relay-validate-ssh-option (substring option 2)))
         ((member option '("-i" "-l" "-p"))
          (unless remaining
            (user-error "Relay SSH option %s requires one argument" option))
          (my/agent-events-relay-ssh-argument
           (pop remaining) (format "Relay SSH %s argument" option)))
         ((member option '("-4" "-6" "-C" "-q" "-v")) nil)
         (t
          (user-error "Relay SSH option %s is not allowlisted" option)))))
  options))

(defun my/agent-events-relay-validate-config (configuration)
  "Return CONFIGURATION with trusted TRAMP and remote-socket fields derived.

Only the TRAMP prefix and identity come from the configured root.  SSH argv is
drawn solely from the explicit destination and options in CONFIGURATION.
"
  (let* ((name (my/agent-events-relay-name (plist-get configuration :name)))
         (root (plist-get configuration :workspace-root))
         (destination
          (my/agent-events-relay-ssh-argument
           (plist-get configuration :ssh-destination) "Relay SSH destination"))
         (options (my/agent-events-relay-ssh-options
                   (plist-get configuration :ssh-options)))
         (remote-socket (my/agent-events-validate-remote-localname
                         (plist-get configuration :remote-socket)
                         "Remote relay socket" my/agent-events-max-cwd-bytes)))
    (unless (and (stringp root) (file-remote-p root))
      (user-error "Relay workspace root must be a TRAMP directory"))
    (when (or (string-prefix-p "-" destination)
              (string-match-p "[[:space:]]" destination))
      (user-error "Relay SSH destination must be one non-option host argument"))
    (my/agent-events-validate-unix-socket-path remote-socket "Remote relay socket")
    (let* ((tramp-name (tramp-dissect-file-name root))
           (prefix (file-remote-p root))
           (local-root (tramp-file-name-localname tramp-name))
           (remote-directory (file-name-directory remote-socket)))
      (setq local-root (my/agent-events-remote-directory-identity
                        local-root "TRAMP workspace local root"
                        my/agent-events-max-workspace-root-bytes)
            root (concat prefix (file-name-as-directory local-root)))
      (unless (equal (plist-get configuration :workspace-root) root)
        (user-error "Relay workspace root must be an exact normalized TRAMP directory"))
      (unless (and remote-directory
                   (not (equal remote-directory "/"))
                   (equal remote-socket
                          (expand-file-name
                           (file-name-nondirectory remote-socket) remote-directory))
                   (not (string-match-p ":" remote-socket)))
        (user-error "Remote relay socket must be a direct non-root private-directory child"))
      (list :name name
            :workspace-root root
            :ssh-destination destination
            :ssh-options options
            :remote-socket remote-socket
            :remote-directory remote-directory
            :tramp-prefix prefix
            :local-root local-root
            :tramp-method (tramp-file-name-method tramp-name)
            :tramp-user (tramp-file-name-user tramp-name)
            :tramp-host (tramp-file-name-host tramp-name)
            :tramp-hop (tramp-file-name-hop tramp-name)))))

(defun my/agent-events-relay-config (name)
  "Return NAME's unique validated relay configuration from user configuration."
  (let* ((name (my/agent-events-relay-name name))
         (matches
          (seq-filter
           (lambda (configuration)
             (equal (my/agent-events-relay-name (plist-get configuration :name)) name))
           my/agent-events-relays)))
    (unless (= (length matches) 1)
      (user-error "Relay %s is not configured exactly once" name))
    (let ((result (my/agent-events-relay-validate-config (car matches))))
      (when (> (length
                (seq-filter
                 (lambda (configuration)
                   (equal (plist-get (my/agent-events-relay-validate-config configuration)
                                     :workspace-root)
                          (plist-get result :workspace-root)))
                 my/agent-events-relays))
               1)
        (user-error "Only one relay may use workspace root %s"
                    (plist-get result :workspace-root)))
      result)))

(defun my/agent-events-relay-directory ()
  "Return the validated private local directory used by relay listeners."
  (let ((directory (file-name-as-directory (expand-file-name my/agent-events-relay-directory))))
    (when (file-remote-p directory)
      (user-error "Relay listener directory must be local"))
    (unless (file-exists-p directory)
      (make-directory directory)
      (set-file-modes directory #o700))
    (let ((attributes (file-attributes directory 'integer)))
      (unless (and attributes
                   (eq (file-attribute-type attributes) t)
                   (= (file-attribute-user-id attributes) (user-uid))
                   (= (logand (file-modes directory 'nofollow) #o777) #o700))
        (user-error "Relay listener directory must be owned, non-symlink, and mode 0700")))
    directory))

(defun my/agent-events-relay-socket-attributes (path)
  "Return PATH attributes only when it is this user's exact-mode Unix socket."
  (let ((attributes (file-attributes path 'integer)))
    (when (and attributes
               (stringp (file-attribute-modes attributes))
               (string-prefix-p "s" (file-attribute-modes attributes))
               (= (file-attribute-user-id attributes) (user-uid))
               (= (logand (file-modes path 'nofollow) #o777) #o600))
      attributes)))

(defun my/agent-events-relay-delete-local-socket (state)
  "Delete STATE's listener socket only when its recorded identity still matches."
  (let* ((path (plist-get state :listener-path))
         (directory (plist-get state :listener-directory))
         (attributes (and path (my/agent-events-relay-socket-attributes path))))
    (when (and path directory
               (equal (file-name-directory path) directory)
               attributes
               (equal (file-attribute-device-number attributes)
                      (plist-get state :listener-device))
               (equal (file-attribute-inode-number attributes)
               (plist-get state :listener-inode)))
      (delete-file path))))

(defun my/agent-events-relay-local-socket-name (state)
  "Return STATE's short hashed local listener filename.

The configured relay name remains a human-facing identity, while this bounded
filename leaves most AF_UNIX path capacity for the user-configured directory.
"
  (format "relay-%s-%d.sock"
          (substring (secure-hash 'sha256 (plist-get state :name)) 0 16)
          (plist-get state :generation)))

(defun my/agent-events-relay-shell-script (operation configuration &optional identity)
  "Return fixed remote shell OPERATION using safely quoted CONFIGURATION values."
  (let ((directory (shell-quote-argument (plist-get configuration :remote-directory)))
        (socket (shell-quote-argument (plist-get configuration :remote-socket)))
        (expected (and identity (shell-quote-argument identity))))
    (pcase operation
      ('preflight
       (concat
        "dir=" directory "; socket=" socket "; uid=$(id -u) || exit 1; "
        "if [ -e \"$dir\" ] || [ -L \"$dir\" ]; then "
        "[ ! -L \"$dir\" ] && [ -d \"$dir\" ] || exit 1; "
        "set -- $(stat -c '%u %a' -- \"$dir\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 700 ] || exit 1; "
        "else mkdir -- \"$dir\" && chmod 700 -- \"$dir\" || exit 1; fi; "
        "if [ -e \"$socket\" ] || [ -L \"$socket\" ]; then "
        "[ ! -L \"$socket\" ] && [ -S \"$socket\" ] || exit 1; "
        "set -- $(stat -c '%u %a %d:%i' -- \"$socket\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 600 ] || exit 1; stale=$3; "
        "set -- $(stat -c '%u %a %d:%i' -- \"$socket\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 600 ] && "
        "[ \"$3\" = \"$stale\" ] && rm -- \"$socket\" || exit 1; fi"))
      ('postverify
       (concat
        "dir=" directory "; socket=" socket "; uid=$(id -u) || exit 1; "
        "[ ! -L \"$dir\" ] && [ -d \"$dir\" ] || exit 1; "
        "set -- $(stat -c '%u %a' -- \"$dir\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 700 ] || exit 1; "
        "[ ! -L \"$socket\" ] && [ -S \"$socket\" ] || exit 1; "
        "set -- $(stat -c '%u %a %d:%i' -- \"$socket\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 600 ] || exit 1; "
        "printf '%s\\n' \"$3\""))
      ('cleanup
       (concat
        "dir=" directory "; socket=" socket "; expected=" expected
        "; uid=$(id -u) || exit 1; "
        "[ ! -L \"$dir\" ] && [ -d \"$dir\" ] || exit 1; "
        "set -- $(stat -c '%u %a' -- \"$dir\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 700 ] || exit 1; "
        "[ ! -L \"$socket\" ] && [ -S \"$socket\" ] || exit 1; "
        "set -- $(stat -c '%u %a %d:%i' -- \"$socket\") || exit 1; "
        "[ \"$1\" = \"$uid\" ] && [ \"$2\" = 600 ] || exit 1; "
        "[ \"$3\" = \"$expected\" ] && rm -- \"$socket\"")))))

(defun my/agent-events-relay-ssh-required-options ()
  "Return fixed SSH options required for every explicit relay connection."
  (list "-F" "none"
        "-o" "BatchMode=yes"
        "-o" "ConnectTimeout=10"))

(defun my/agent-events-relay-maintenance-command (configuration operation &optional identity)
  "Return SSH argv for one quoted remote maintenance OPERATION.

The final argv member is the complete remote command.  It is quoted once for
the remote login shell, so remote path values never become separate SSH remote
command arguments.
"
  (let ((script (my/agent-events-relay-shell-script operation configuration identity)))
    (append (list "ssh")
            (my/agent-events-relay-ssh-required-options)
            (plist-get configuration :ssh-options)
            (list "-T"
                  (plist-get configuration :ssh-destination)
                  (concat "sh -c " (shell-quote-argument script))))))

(defun my/agent-events-relay-wait-for-exit (process timeout)
  "Wait at most TIMEOUT seconds for local PROCESS to exit and be reaped."
  (let ((deadline (+ (float-time) timeout)))
    (while (and (process-live-p process) (< (float-time) deadline))
      (accept-process-output process (max 0 (min 0.05 (- deadline (float-time))))))
    (unless (process-live-p process)
      (accept-process-output process 0))
    (not (process-live-p process))))

(defun my/agent-events-relay-terminate-process (process)
  "Terminate and reap local PROCESS within the relay's finite shutdown bound."
  (when (process-live-p process)
    (delete-process process)
    (my/agent-events-relay-wait-for-exit
     process my/agent-events-relay-termination-timeout))
  (not (process-live-p process)))

(defun my/agent-events-relay-run-ssh (configuration operation &optional identity)
  "Run one bounded explicit local SSH OPERATION and return successful stdout.

This intentionally never executes through a TRAMP `default-directory'.  A
timed-out local SSH maintenance process is terminated and reaped before this
function signals its failure.
"
  (let ((buffer (generate-new-buffer " *agent-events-relay-ssh*"))
        (default-directory temporary-file-directory)
        process
        result)
    (unwind-protect
        (progn
          (setq process
                (make-process
                 :name "my-agent-events-relay-ssh-maintenance"
                 :command (my/agent-events-relay-maintenance-command
                           configuration operation identity)
                 :buffer buffer
                 :connection-type 'pipe
                 :noquery t))
          (unless (my/agent-events-relay-wait-for-exit
                   process my/agent-events-relay-maintenance-timeout)
            (unless (my/agent-events-relay-terminate-process process)
              (user-error "Relay SSH maintenance process did not terminate"))
            (user-error "Relay SSH maintenance command timed out"))
          (when (and (eq (process-status process) 'exit)
                     (zerop (process-exit-status process)))
            (setq result (string-trim (with-current-buffer buffer (buffer-string))))))
      (when (and (processp process) (process-live-p process))
        (my/agent-events-relay-terminate-process process))
      (kill-buffer buffer))
    result))

(defun my/agent-events-relay-remote-cleanup (state)
  "Remove STATE's remote socket only through its recorded postverify identity."
  (let ((configuration (plist-get state :config))
        (identity (plist-get state :remote-identity)))
    (when (and configuration identity)
      (condition-case nil
          (my/agent-events-relay-run-ssh configuration 'cleanup identity)
        (error nil)))))

(defun my/agent-events-relay-state-put (state)
  "Store STATE under its configured relay name and return it."
  (puthash (plist-get state :name) state my/agent-events-relay-states)
  state)

(defun my/agent-events-relay-remove-client (client)
  "Remove CLIENT from its matching live relay state's child list."
  (let* ((name (process-get client 'my/agent-events-relay-name))
         (generation (process-get client 'my/agent-events-relay-generation))
         (state (and name (gethash name my/agent-events-relay-states))))
    (when (and state (= generation (plist-get state :generation)))
      (setf (plist-get state :clients) (delq client (plist-get state :clients)))
      (my/agent-events-relay-state-put state))))

(defun my/agent-events-relay-close-client (client reason)
  "Close CLIENT once, canceling its deadline and recording concise REASON."
  (unless (process-get client 'my/agent-events-relay-closed)
    (process-put client 'my/agent-events-relay-closed t)
    (let ((timer (process-get client 'my/agent-events-relay-deadline)))
      (when (timerp timer)
        (cancel-timer timer)))
    (my/agent-events-relay-remove-client client)
    (condition-case nil
        (delete-process client)
      (error nil))
    (message "Agent relay %s closed a client: %s"
             (or (process-get client 'my/agent-events-relay-name) "unknown") reason)))

(defun my/agent-events-relay-client-deadline (client)
  "Close CLIENT when its non-resetting total read deadline expires."
  (condition-case nil
      (my/agent-events-relay-close-client client "read deadline")
    (error nil)))

(defun my/agent-events-relay-decode-frame (bytes)
  "Decode UTF-8 BYTES, rejecting Emacs raw-byte placeholders for invalid input."
  (let ((result (decode-coding-string bytes 'utf-8)))
    (when (seq-some (lambda (character) (> character (max-char t))) result)
      (user-error "Relay frame is not valid UTF-8"))
    result))

(defun my/agent-events-relay-deferred-process (name generation raw)
  "Process queued remote RAW only for NAME's still-active GENERATION."
  (let ((state (gethash name my/agent-events-relay-states)))
    (when (and state (= generation (plist-get state :generation)))
      (setf (plist-get state :pending) (max 0 (1- (plist-get state :pending))))
      (my/agent-events-relay-state-put state)
      (when (plist-get state :active)
        (condition-case err
            (my/agent-events-process-event
             (my/agent-events-parse-remote raw (plist-get state :config)))
          (error
           (message "Rejected remote agent event for relay %s: %s"
                    name (error-message-string err))))))))

(defun my/agent-events-relay-client-filter (client chunk)
  "Accept exactly one bounded LF-terminated UTF-8 JSON frame from CLIENT."
  (condition-case err
      (unless (process-get client 'my/agent-events-relay-closed)
        (let* ((frame (or (process-get client 'my/agent-events-relay-frame)
                          (encode-coding-string "" 'binary)))
               (size (+ (string-bytes frame) (string-bytes chunk)))
               (combined (and (<= size (1+ my/agent-events-max-raw-bytes))
                              (concat frame chunk))))
          (if (null combined)
              (my/agent-events-relay-close-client client "oversize frame")
            (let ((newline (cl-position ?\n combined)))
              (if (null newline)
                  (progn
                    (process-put client 'my/agent-events-relay-frame combined)
                    (when (> (string-bytes combined) my/agent-events-max-raw-bytes)
                      (my/agent-events-relay-close-client client "oversize frame")))
                (let ((payload (substring combined 0 newline))
                      (trailing (substring combined (1+ newline))))
                  (cond
                   ((zerop (string-bytes payload))
                    (my/agent-events-relay-close-client client "empty frame"))
                   ((string-suffix-p "\r" payload)
                    (my/agent-events-relay-close-client client "non-LF frame delimiter"))
                   ((> (string-bytes payload) my/agent-events-max-raw-bytes)
                    (my/agent-events-relay-close-client client "oversize frame"))
                   ((not (string-empty-p trailing))
                    (my/agent-events-relay-close-client client "extra frame data"))
                   (t
                    (let* ((raw (my/agent-events-relay-decode-frame payload))
                           (name (process-get client 'my/agent-events-relay-name))
                           (generation (process-get client 'my/agent-events-relay-generation))
                           (state (gethash name my/agent-events-relay-states)))
                      (unless (and state (= generation (plist-get state :generation))
                                   (plist-get state :active))
                        (user-error "Relay generation is no longer active"))
                      (if (>= (plist-get state :pending) my/agent-events-listener-max-pending)
                          (my/agent-events-relay-close-client client "pending frame limit")
                        (setf (plist-get state :pending) (1+ (plist-get state :pending)))
                        (my/agent-events-relay-state-put state)
                        (my/agent-events-relay-close-client client "frame accepted")
                        (run-at-time 0 nil #'my/agent-events-relay-deferred-process
                                     name generation raw)))))))))))
    (error
     (my/agent-events-relay-close-client client "malformed frame")
     (message "Agent relay filter rejected input: %s" (error-message-string err)))))

(defun my/agent-events-relay-client-sentinel (client event)
  "Close CLIENT on EOF or failed connection state in EVENT, not initial open."
  (ignore event)
  (condition-case nil
      (when (and (not (process-get client 'my/agent-events-relay-closed))
                 (memq (process-status client) '(closed failed exit signal)))
        (my/agent-events-relay-close-client client "connection closed before one frame"))
    (error nil)))

(defun my/agent-events-relay-listener-log (server client message)
  "Initialize or reject accepted CLIENT for relay SERVER without trusting MESSAGE."
  (ignore message)
  (condition-case err
      (let* ((name (process-get server 'my/agent-events-relay-name))
             (generation (process-get server 'my/agent-events-relay-generation))
             (state (gethash name my/agent-events-relay-states)))
        (process-put client 'my/agent-events-relay-name name)
        (process-put client 'my/agent-events-relay-generation generation)
        (if (or (null state) (/= generation (plist-get state :generation))
                (not (plist-get state :active))
                (>= (length (plist-get state :clients))
                    my/agent-events-listener-max-clients))
            (my/agent-events-relay-close-client client "connection limit")
          (process-put client 'my/agent-events-relay-frame
                       (encode-coding-string "" 'binary))
          (process-put client 'my/agent-events-relay-deadline
                       (run-at-time my/agent-events-listener-deadline nil
                                    #'my/agent-events-relay-client-deadline client))
          (push client (plist-get state :clients))
          (my/agent-events-relay-state-put state)))
    (error
     (condition-case nil
         (my/agent-events-relay-close-client client "listener setup failed")
       (error nil))
     (message "Agent relay listener rejected a client: %s" (error-message-string err)))))

(defun my/agent-events-relay-create-listener (state)
  "Create STATE's generation-specific local Unix listener and record identity."
  (let* ((directory (my/agent-events-relay-directory))
         (path (expand-file-name
                (my/agent-events-relay-local-socket-name state)
                directory)))
    (my/agent-events-validate-unix-socket-path path "Local relay socket")
    (when (or (file-exists-p path) (file-symlink-p path))
      (user-error "Refusing to replace an existing relay listener socket"))
    (let ((listener
           (make-network-process
            :name (format "my-agent-events-relay-%s" (plist-get state :name))
            :family 'local
            :service path
            :server 5
            :coding 'binary
            :filter-multibyte nil
            :filter #'my/agent-events-relay-client-filter
            :sentinel #'my/agent-events-relay-client-sentinel
            :log #'my/agent-events-relay-listener-log
            :noquery t)))
      (set-file-modes path #o600)
      (let ((attributes (my/agent-events-relay-socket-attributes path)))
        (unless attributes
          (delete-process listener)
          (user-error "Relay listener socket permissions are unsafe"))
        (process-put listener 'my/agent-events-relay-name (plist-get state :name))
        (process-put listener 'my/agent-events-relay-generation
                     (plist-get state :generation))
        (plist-put state :listener listener)
        (plist-put state :listener-directory directory)
        (plist-put state :listener-path path)
        (plist-put state :listener-device (file-attribute-device-number attributes))
        (plist-put state :listener-inode (file-attribute-inode-number attributes))
        state))))

(defun my/agent-events-relay-tunnel-command (state)
  "Return STATE's dedicated reviewed SSH reverse-forward argv.

`StreamLocalBindUnlink' is deliberately absent: remote cleanup remains under
the ownership/type/identity checks in this module.
"
  (let ((configuration (plist-get state :config)))
    (append (list "ssh")
            (my/agent-events-relay-ssh-required-options)
            (plist-get configuration :ssh-options)
            (list "-N" "-T"
                  "-o" "ExitOnForwardFailure=yes"
                  "-o" "StreamLocalBindMask=0177"
                  "-R" (concat (plist-get configuration :remote-socket) ":"
                                 (plist-get state :listener-path))
                  (plist-get configuration :ssh-destination)))))

(defun my/agent-events-relay-tunnel-sentinel (process event)
  "Clean local resources for PROCESS's matching tunnel exit without reconnecting."
  (ignore event)
  (condition-case nil
      (let* ((name (process-get process 'my/agent-events-relay-name))
             (generation (process-get process 'my/agent-events-relay-generation))
             (state (and name (gethash name my/agent-events-relay-states))))
        (when (and state (= generation (plist-get state :generation))
                   (not (plist-get state :stopping))
                   (not (process-live-p process)))
          (plist-put state :active nil)
          (plist-put state :tunnel nil)
          (my/agent-events-relay-state-put state)
          (my/agent-events-relay-stop-state state t)
          (message "Agent relay %s tunnel stopped" name)))
    (error nil)))

(defun my/agent-events-relay-start-tunnel (state)
  "Start STATE's SSH tunnel, confirm it remains live, and return STATE."
  (let ((default-directory temporary-file-directory)
        (process
         (make-process :name (format "my-agent-events-relay-ssh-%s"
                                     (plist-get state :name))
                       :command (my/agent-events-relay-tunnel-command state)
                       :connection-type 'pipe
                       :noquery t
                       :sentinel #'my/agent-events-relay-tunnel-sentinel)))
    (process-put process 'my/agent-events-relay-name (plist-get state :name))
    (process-put process 'my/agent-events-relay-generation (plist-get state :generation))
    (accept-process-output process my/agent-events-relay-tunnel-readiness-timeout)
    (unless (process-live-p process)
      (user-error "Relay SSH tunnel did not stay live"))
    (plist-put state :tunnel process)
    state))

(defun my/agent-events-relay-stop-state (state &optional skip-remote-cleanup)
  "Disable and tear down one STATE in the required secure restart order.

When SKIP-REMOTE-CLEANUP is non-nil, only local resources are removed.  The
tunnel sentinel uses that path after an unexpected exit so cleanup never opens
a replacement SSH connection.
"
  (when (and state (not (plist-get state :stopping)))
    (plist-put state :stopping t)
    (plist-put state :active nil)
    (my/agent-events-relay-state-put state)
    (let ((tunnel (plist-get state :tunnel))
          tunnel-live)
      (when (processp tunnel)
        (condition-case nil
            (delete-process tunnel)
          (error nil))
        (let ((attempts 20))
          (while (and (process-live-p tunnel) (> attempts 0))
            (accept-process-output tunnel 0.05)
            (setq attempts (1- attempts)))
          (setq tunnel-live (process-live-p tunnel))))
      (if tunnel-live
          (message "Agent relay %s tunnel did not stop" (plist-get state :name))
        (unless skip-remote-cleanup
          (my/agent-events-relay-remote-cleanup state)))
      (dolist (client (copy-sequence (plist-get state :clients)))
        (my/agent-events-relay-close-client client "relay stopped"))
      (let ((listener (plist-get state :listener)))
        (when (processp listener)
          (condition-case nil
              (delete-process listener)
            (error nil))))
      (condition-case nil
          (my/agent-events-relay-delete-local-socket state)
        (error nil))
      (plist-put state :clients nil)
      (plist-put state :listener nil)
      (unless tunnel-live
        (plist-put state :tunnel nil))
      (plist-put state :stopping nil)
      (my/agent-events-relay-state-put state)))
  state)

(defun my/agent-events-relay-read-name ()
  "Read one configured relay name for an interactive lifecycle command."
  (completing-read "Relay: "
                   (mapcar (lambda (configuration)
                             (my/agent-events-relay-name (plist-get configuration :name)))
                           my/agent-events-relays)
                   nil t))

(defun my/agent-events-relay-start (name)
  "Start configured remote relay NAME without inferring any transport values."
  (interactive (list (my/agent-events-relay-read-name)))
  (let* ((configuration (my/agent-events-relay-config name))
         (name (plist-get configuration :name))
         (old-state (gethash name my/agent-events-relay-states))
         (generation (setq my/agent-events-relay-generation
                           (1+ my/agent-events-relay-generation)))
         (state (list :name name :config configuration :generation generation
                      :active nil :clients nil :pending 0)))
    (when old-state
      (my/agent-events-relay-stop-state old-state)
      (when (process-live-p (plist-get old-state :tunnel))
        (user-error "Relay SSH tunnel did not stop; refusing replacement")))
    (my/agent-events-relay-state-put state)
    (condition-case err
        (progn
          (setq state (my/agent-events-relay-create-listener state))
          (my/agent-events-relay-state-put state)
          (unless (my/agent-events-relay-run-ssh configuration 'preflight)
            (user-error "Relay remote preflight failed"))
          (setq state (my/agent-events-relay-start-tunnel state))
          (my/agent-events-relay-state-put state)
          (let ((identity (my/agent-events-relay-run-ssh configuration 'postverify)))
            (unless (and identity (string-match-p "\\`[^[:space:]]+:[^[:space:]]+\\'" identity))
              (user-error "Relay remote socket verification failed"))
            (plist-put state :remote-identity identity))
          (plist-put state :active t)
          (my/agent-events-relay-state-put state)
          state)
      (error
       (my/agent-events-relay-stop-state state)
       (message "Agent relay %s failed to start: %s" name (error-message-string err))
       nil))))

(defun my/agent-events-relay-stop (name)
  "Stop configured relay NAME, preserving the terminal agent workflow on failure."
  (interactive (list (my/agent-events-relay-read-name)))
  (let ((state (gethash (my/agent-events-relay-name name)
                        my/agent-events-relay-states)))
    (when state
      (my/agent-events-relay-stop-state state))
    state))

(defun my/agent-events-relay-restart (name)
  "Securely replace configured relay NAME with one new generation."
  (interactive (list (my/agent-events-relay-read-name)))
  (my/agent-events-relay-stop name)
  (my/agent-events-relay-start name))

(defun my/agent-events-relay-status (&optional name)
  "Return one relay state for NAME, or all configured runtime states.

This function reports only current Emacs state.  It does not auto-connect or
attempt to repair an inactive relay.
"
  (interactive)
  (let ((result
         (if name
             (gethash (my/agent-events-relay-name name)
                      my/agent-events-relay-states)
           (let (states)
             (maphash (lambda (relay-name state)
                        (push (cons relay-name state) states))
                      my/agent-events-relay-states)
             (nreverse states)))))
    (when (called-interactively-p 'interactive)
      (message "%s" (if result "Agent relay status available" "No agent relay state")))
    result))

(defun my/agent-events-relay-socket-for-root (root)
  "Return ROOT's active configured remote event socket, or nil.

ROOT must already be the exact normalized trusted TRAMP root.  This is a
read-only lookup for remote terminal launchers; it neither starts a relay nor
uses connection state from TRAMP.
"
  (let (matches)
    (when (and (stringp root) (file-remote-p root)
               (equal root (file-name-as-directory root)))
      (maphash
       (lambda (name state)
         (ignore name)
         (let ((configuration (plist-get state :config)))
           (when (and (plist-get state :active)
                      (equal root (plist-get configuration :workspace-root)))
             (push (plist-get configuration :remote-socket) matches))))
       my/agent-events-relay-states))
    (when (= (length matches) 1)
      (car matches))))

(defun my/agent-events-relay-stop-all ()
  "Stop every started relay without starting or configuring new ones."
  (interactive)
  (let (states)
    (maphash (lambda (name state)
               (ignore name)
               (push state states))
             my/agent-events-relay-states)
    (dolist (state states)
      (my/agent-events-relay-stop-state state))
    nil))

(add-hook 'kill-emacs-hook #'my/agent-events-relay-stop-all)

(provide 'my-agent-events)

;;; my-agent-events.el ends here
