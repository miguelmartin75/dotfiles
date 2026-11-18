;;; my-agent-events-test.el --- Tests for bounded local agent events -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'json)
(require 'org)
(require 'seq)
(require 'server)

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'my-agent-events)

(defconst my/agent-events-test-directory
  (file-name-directory (expand-file-name (or load-file-name buffer-file-name)))
  "Directory holding the staged event module and its tests.")

(defconst my/agent-events-test-server-expression
  "(let ((arguments server-eval-args-left)) (setq server-eval-args-left nil) (unless (= (length arguments) 1) (user-error \"Expected one agent event payload\")) (my/agent-events-ingest (car arguments)))"
  "The wrapper's fixed server expression, exercised as data-only ingress.")

(defmacro my/agent-events-test-with-storage (&rest body)
  "Run BODY with isolated workflow files and workspace directories."
  (declare (indent 0) (debug t))
  `(let* ((temporary-root (make-temp-file "my-agent-events-test-" t))
          (workspace (expand-file-name "workspace/" temporary-root))
          (workspace-two (expand-file-name "workspace-two/" temporary-root))
          (my/workflow-project-storage-root
           (expand-file-name "projects/" temporary-root))
          (my/workflow-journal-file (expand-file-name "journal.org" temporary-root))
          (my/workflow-life-file (expand-file-name "life.org" temporary-root))
          (org-directory temporary-root)
          (org-id-locations nil)
          (org-id-locations-file (expand-file-name ".org-id-locations" temporary-root))
          (org-agenda-files nil)
          (default-directory temporary-root))
     (make-directory workspace t)
     (make-directory workspace-two t)
     (unwind-protect
         (progn ,@body)
       (dolist (buffer (buffer-list))
         (when (and (buffer-file-name buffer)
                    (string-prefix-p temporary-root (buffer-file-name buffer)))
           (set-buffer-modified-p nil)
           (kill-buffer buffer)))
       (delete-directory temporary-root t))))

(defmacro my/agent-events-test-with-tabs (&rest body)
  "Run BODY with a public tab-bar API model and no real frame state."
  (declare (indent 0) (debug t))
  `(let ((tabs (list '(current-tab (name . "first")))))
     (cl-letf
         (((symbol-function 'tab-bar-tabs)
          (lambda (&optional ignored-frame)
            (ignore ignored-frame)
            tabs))
          ((symbol-function 'tab-bar-tabs-set)
          (lambda (new-tabs &optional ignored-frame)
            (ignore ignored-frame)
            (setq tabs new-tabs)))
          ((symbol-function 'tab-bar-new-tab)
           (lambda (&optional ignored-frame)
             (ignore ignored-frame)
             (setq tabs
                   (append
                    (mapcar (lambda (tab)
                              (if (eq (car tab) 'current-tab)
                                  (cons 'tab (cdr tab))
                                tab))
                            tabs)
                    (list '(current-tab (name . "new"))))))
          ((symbol-function 'tab-bar-select-tab)
           (lambda (index &optional ignored-frame)
             (ignore ignored-frame)
             (setq tabs
                   (cl-loop for tab in tabs
                            for tab-index from 1
                            collect (cons (if (= index tab-index) 'current-tab 'tab)
                                          (cdr tab))))))
       ,@body)))))

(defun my/agent-events-test-json (cwd &rest members)
  "Return one valid v1 JSON event for CWD, overridden by MEMBERS pairs."
  (let ((event (make-hash-table :test 'equal)))
    (dolist (member `(("schema_version" . 1)
                      ("provider" . "codex")
                      ("session_id" . "session")
                      ("event_id" . "event")
                      ("kind" . "progress")
                      ("timestamp" . "2026-09-04T12:00:00Z")
                      ("cwd" . ,cwd)
                      ("title" . "Progress")
                      ("body" . "Working")
                      ("changed_paths" . ["src/file.el"])))
      (puthash (car member) (cdr member) event))
    (while members
      (puthash (pop members) (pop members) event))
    (json-serialize event)))

(defun my/agent-events-test-file-text (file)
  "Return FILE's contents when it exists, or an empty string."
  (if (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (buffer-string))
    ""))

(ert-deftest my/agent-events-schema-bounds-and-unknown-keys ()
  (my/agent-events-test-with-storage
    (let ((valid (my/agent-events-test-json workspace
                                             "kind" "files-changed"
                                             "sequence" 4
                                             "observed_mtime" 2.5
                                             "observed_size" 8)))
      (should (equal (plist-get (my/agent-events-parse valid) :sequence) 4))
      (dolist
          (raw
           (list
            (my/agent-events-test-json workspace "kind" "launch")
            (my/agent-events-test-json workspace "schema_version" 1.0)
            (my/agent-events-test-json workspace "sequence" 4)
            (my/agent-events-test-json workspace "observed_mtime" 2.5)
            (my/agent-events-test-json workspace "observed_size" 8)
            (my/agent-events-test-json workspace "changed_paths" ["/tmp/file"])
            (my/agent-events-test-json workspace "changed_paths" ["../file"])
            (my/agent-events-test-json workspace "changed_paths" ["~/file"])
            (my/agent-events-test-json workspace "changed_paths" ["/ssh:host:/tmp/file"])
            (my/agent-events-test-json workspace "title"
                                       (make-string (1+ my/agent-events-max-title-bytes) ?x))
            (my/agent-events-test-json workspace "unexpected" "value")))
        (should-error (my/agent-events-parse raw) :type 'user-error))
      (should-error
       (my/agent-events-ingest
        (make-string (1+ my/agent-events-max-raw-bytes) ?x))
       :type 'user-error))))

(ert-deftest my/agent-events-deferred-ingress-and-deduplication ()
  (my/agent-events-test-with-storage
    (let* ((raw (my/agent-events-test-json
                 workspace "title" "(setq my/agent-events-test-marker 'changed)"))
           scheduled
           (my/agent-events-seen-ids (make-hash-table :test 'equal))
           (my/agent-events-test-marker 'safe))
      (unwind-protect
          (progn
            (cl-letf (((symbol-function 'run-at-time)
                       (lambda (&rest arguments)
                         (setq scheduled arguments)
                         'agent-event-timer)))
              (should (eq (my/agent-events-ingest raw) 'agent-event-timer)))
            (should-not (get-buffer my/agent-events-buffer-name))
            (should (equal (nth 3 scheduled) raw))
            (funcall (nth 2 scheduled) (nth 3 scheduled))
            (my/agent-events-process raw)
            (with-current-buffer (get-buffer my/agent-events-buffer-name)
              (goto-char (point-min))
              (should (get-text-property (point) 'my/agent-event))
              (should (= (how-many "\n" (point-min) (point-max)) 3)))
            (should (eq my/agent-events-test-marker 'safe)))
        (when (get-buffer my/agent-events-buffer-name)
          (kill-buffer my/agent-events-buffer-name))))))

(ert-deftest my/agent-events-routing-is-explicit-and-cwd-safe ()
  (my/agent-events-test-with-storage
    (my/agent-events-test-with-tabs
      (cl-letf (((symbol-function 'my/workflow-open-task) (lambda (task) task)))
        (let* ((first (my/work-start "First" workspace "one" "first"))
               (second (my/work-start "Second" workspace-two "two" "second"))
               (first-root (plist-get first :root))
               (second-root (plist-get second :root)))
          (cl-letf (((symbol-function 'my/workspace-normalize-root)
                     (lambda (directory)
                       (cond
                        ((string-prefix-p workspace-two (expand-file-name directory))
                         second-root)
                        ((string-prefix-p workspace (expand-file-name directory))
                         first-root)
                        (t (file-name-as-directory (expand-file-name directory)))))))
            (let ((explicit
                   (my/agent-events-route
                    (my/agent-events-parse
                     (my/agent-events-test-json workspace
                                                "task_id" (plist-get first :id)
                                                "workspace_root" first-root)))))
              (should (eq (plist-get explicit :route) 'bound))
              (should (equal (plist-get (plist-get explicit :task) :id)
                             (plist-get first :id))))
            (let ((cwd-only
                   (my/agent-events-route
                    (my/agent-events-parse (my/agent-events-test-json workspace-two)))))
              (should (eq (plist-get cwd-only :route) 'bound))
              (should (equal (plist-get (plist-get cwd-only :task) :id)
                             (plist-get second :id))))
            (should-error
             (my/agent-events-route
              (my/agent-events-parse
               (my/agent-events-test-json workspace-two
                                          "task_id" (plist-get first :id)
                                          "workspace_root" second-root)))
             :type 'user-error)
            (setq tabs
                  (seq-remove
                   (lambda (tab)
                     (equal (alist-get 'my/workspace-root (cdr tab)) first-root))
                   tabs))
            (should
             (eq
              (plist-get
               (my/agent-events-route
                (my/agent-events-parse
                 (my/agent-events-test-json workspace
                                            "task_id" (plist-get first :id)
                                            "workspace_root" first-root)))
               :route)
              'unbound))
            (setq tabs
                  (append tabs
                          (list `(tab (name . "duplicate")
                                     (my/workspace-root . ,second-root)
                                     (my/work-task-id . ,(plist-get second :id))))))
            (should
             (eq
              (plist-get
               (my/agent-events-route
                (my/agent-events-parse (my/agent-events-test-json workspace-two)))
               :route)
              'ambiguous))))))))

(ert-deftest my/agent-events-cwd-routing-rejects-stale-cross-root-tab-task ()
  (my/agent-events-test-with-storage
    (my/agent-events-test-with-tabs
      (cl-letf (((symbol-function 'my/workflow-open-task) (lambda (task) task)))
        (let* ((first (my/work-start "First" workspace "one" "first"))
               (second (my/work-start "Second" workspace-two "two" "second"))
               (second-root (plist-get second :root))
               (second-tab
                (seq-find
                 (lambda (tab)
                   (equal (alist-get 'my/workspace-root (cdr tab)) second-root))
                 tabs)))
          (setf (alist-get 'my/work-task-id (cdr second-tab))
                (plist-get first :id))
          (should-error
           (my/agent-events-route
            (my/agent-events-parse
             (my/agent-events-test-json workspace-two)))
           :type 'user-error))))))

(ert-deftest my/agent-events-presentation-does-not-select-a-window ()
  (let* ((event (list :provider "codex"
                      :session-id "session"
                      :event-id "event"
                      :kind "attention"
                      :timestamp "2026-09-04T12:00:00Z"
                      :title "Need review"
                      :body "A change needs review."
                      :changed-paths '("src/file.el")
                      :route 'unbound))
         (before (selected-window))
         displays)
    (unwind-protect
        (cl-letf (((symbol-function 'display-buffer)
                   (lambda (buffer action)
                     (push (list buffer action) displays)
                     (selected-window))))
          (my/agent-events-present event)
          (should (equal (selected-window) before))
          (should (= (length displays) 1))
          (should (equal (cdr (assq 'inhibit-same-window (cadr (car displays)))) t))
          (with-current-buffer (get-buffer my/agent-events-buffer-name)
            (goto-char (point-min))
            (should (derived-mode-p 'my/agent-events-mode))
            (should (equal (get-text-property (point) 'my/agent-event) event)))
          (should (equal my/agent-events-mode-line-status " Agent:attention")))
      (when (get-buffer my/agent-events-buffer-name)
        (kill-buffer my/agent-events-buffer-name)))))

(ert-deftest my/agent-events-selected-done-log-is-reviewed-and-keeps-tab-focus ()
  (my/agent-events-test-with-storage
    (my/agent-events-test-with-tabs
      (cl-letf (((symbol-function 'my/workflow-open-task) (lambda (task) task)))
        (let* ((first (my/work-start "First" workspace "one" "first"))
               (second (my/work-start "Second" workspace-two "two" "second"))
               (event (list :provider "codex"
                            :session-id "session"
                            :event-id "event"
                            :kind "done"
                            :timestamp "2026-09-04T12:00:00Z"
                            :title "Completed parser\nchecks"
                            :body "All tests passed."
                            :changed-paths nil
                            :route 'bound
                            :task first))
               prompt
               before)
          (setq before (my/agent-events-test-file-text my/workflow-journal-file))
          (my/agent-events-render event)
          (should (equal (my/agent-events-test-file-text my/workflow-journal-file) before))
          (with-current-buffer (get-buffer my/agent-events-buffer-name)
            (goto-char (point-min))
            (forward-line 1)
            (cl-letf (((symbol-function 'read-string)
                       (lambda (ignored-prompt initial &rest ignored-arguments)
                         (ignore ignored-prompt ignored-arguments)
                         (setq prompt initial)
                         "Completed after review.")))
              (my/agent-events-log-selected-done)))
          (should-not (string-match-p "[\r\n]" prompt))
          (should (equal (my/tab-current-property 'my/workspace-root)
                         (plist-get second :root)))
          (should (string-match-p "done: Completed after review\."
                                  (my/agent-events-test-file-text
                                   my/workflow-journal-file)))
          (setq before (my/agent-events-test-file-text my/workflow-journal-file))
          (with-current-buffer (get-buffer my/agent-events-buffer-name)
            (goto-char (point-min))
            (forward-line 1)
            (cl-letf (((symbol-function 'read-string)
                       (lambda (&rest ignored-arguments)
                         (ignore ignored-arguments)
                         (signal 'quit nil))))
              (should-error (my/agent-events-log-selected-done) :type 'quit)))
          (should (equal (my/agent-events-test-file-text my/workflow-journal-file)
                         before))
          (kill-buffer my/agent-events-buffer-name))))))

(ert-deftest my/agent-events-server-eval-keeps-hostile-data-inert ()
  (let* ((temporary-root (make-temp-file "my-agent-events-server-" t))
         (server-name (format "ae%d" (random 10000)))
         (module-directory my/agent-events-test-directory)
         (payload
          (my/agent-events-test-json
           temporary-root "title" "(setq my/agent-events-test-sentinel 'changed)"))
         (initial-expression
          (prin1-to-string
           '(progn
              (require 'my-agent-events)
              (setq my/agent-events-test-captured nil
                    my/agent-events-test-sentinel 'safe)
              (defun my/agent-events-ingest (raw)
                (setq my/agent-events-test-captured raw)))))
         (process-environment (cons (concat "XDG_RUNTIME_DIR=" temporary-root)
                                    process-environment))
         started)
    (unwind-protect
        (progn
          (let ((daemon-output (generate-new-buffer " *agent-events-daemon*")))
            (unwind-protect
                (let ((exit-code (call-process "emacs" nil daemon-output nil
                                                "-Q" (concat "--daemon=" server-name)
                                                "-L" module-directory
                                                "--eval" initial-expression)))
                  (unless (zerop exit-code)
                    (ert-fail (with-current-buffer daemon-output (buffer-string)))))
              (kill-buffer daemon-output)))
          (setq started t)
          (let ((attempts 40)
                status)
            (while (and (> attempts 0) (not (eq status 0)))
              (setq status
                    (call-process "emacsclient" nil nil nil
                                  "--socket-name" server-name "--eval" "t"))
              (unless (eq status 0)
                (sleep-for 0.05))
              (setq attempts (1- attempts)))
            (should (eq status 0)))
          (should (zerop (call-process "emacsclient" nil nil nil
                                       "--socket-name" server-name
                                       "--eval" my/agent-events-test-server-expression
                                       "--" payload)))
          (with-temp-buffer
            (should (zerop (call-process "emacsclient" nil t nil
                                         "--socket-name" server-name
                                         "--eval"
                                         "(list my/agent-events-test-captured my/agent-events-test-sentinel)")))
            (goto-char (point-min))
            (let ((result (read (current-buffer))))
              (should (equal (car result) payload))
              (should (eq (cadr result) 'safe)))))
          (let ((server-eval-args-left '("first" "second")))
            (cl-letf (((symbol-function 'my/agent-events-ingest)
                       (lambda (&rest ignored-arguments)
                         (ignore ignored-arguments)
                         (error "must not ingest"))))
              (should-error (eval (read my/agent-events-test-server-expression))
                            :type 'user-error)
              (should-not server-eval-args-left))))
      (when started
        (call-process "emacsclient" nil nil nil
                      "--socket-name" server-name "--eval" "(kill-emacs)"))
      (delete-directory temporary-root t)))

(defun my/agent-events-test-relay (name root local-root)
  "Return a minimal trusted relay plist for NAME, ROOT, and LOCAL-ROOT."
  (list :name name
        :workspace-root root
        :tramp-prefix (file-remote-p root)
        :local-root local-root
        :ssh-destination "example.test"
        :ssh-options nil
        :remote-directory "/run/user/1000/"
        :remote-socket (format "/run/user/1000/%s.sock" name)))

(defun my/agent-events-test-listener-client (state &optional allow-reject)
  "Connect one local test client and return its accepted server-side process.

When ALLOW-REJECT is non-nil, return nil for a listener that correctly refuses
the connection because it has reached its active-child limit.
"
  (let* ((before (copy-sequence (plist-get state :clients)))
         (path (plist-get state :listener-path))
         (client (make-network-process :name "my-agent-events-test-client"
                                       :family 'local :service path
                                       :coding 'binary :filter-multibyte nil
                                       :noquery t))
         result)
    (ignore client)
    (dotimes (attempt 10)
      (ignore attempt)
      (unless result
        (accept-process-output nil 0.05)
        (setq result
              (seq-find (lambda (candidate) (not (memq candidate before)))
                        (plist-get state :clients)))))
    (unless (or result allow-reject)
      (ert-fail "Listener did not accept a test client"))
    result))

(ert-deftest my/agent-events-remote-schema-ordering-and-root-isolation ()
  (let* ((root-one "/sshx:one:/repo/")
         (root-two "/sshx:two:/repo/")
         (relay-one (my/agent-events-test-relay "one" root-one "/repo"))
         (relay-two (my/agent-events-test-relay "two" root-two "/repo"))
         (raw (my/agent-events-test-json
               "/repo/src" "kind" "files-changed" "workspace_root" "/repo"
               "sequence" 4 "observed_mtime" 2.5 "observed_size" 8))
         (my/agent-events-latest-sequences (make-hash-table :test 'equal)))
    (let ((event (my/agent-events-parse-remote raw relay-one)))
      (should (equal (plist-get event :cwd) "/sshx:one:/repo/src"))
      (should (equal (plist-get event :workspace-root) root-one))
      (should (my/agent-events-accept-sequence-p event))
      (should-not (my/agent-events-accept-sequence-p event))
      (let ((lower (copy-sequence event)))
        (plist-put lower :sequence 3)
        (should-not (my/agent-events-accept-sequence-p lower)))
      (let ((higher (copy-sequence event)))
        (plist-put higher :sequence 5)
        (should (my/agent-events-accept-sequence-p higher)))
      (let ((other-session (copy-sequence event)))
        (plist-put other-session :session-id "other-session")
        (plist-put other-session :sequence 1)
        (should (my/agent-events-accept-sequence-p other-session))))
    (should (equal (plist-get
                    (my/agent-events-parse-remote
                     (my/agent-events-test-json
                      "/repo/src/" "workspace_root" "/repo/")
                     relay-one)
                    :cwd)
                   "/sshx:one:/repo/src"))
    (let ((other-root (my/agent-events-parse-remote raw relay-two)))
      (should (my/agent-events-accept-sequence-p other-root))
      (should (equal (plist-get other-root :source) root-two)))
    (dolist (invalid
             (list
              (my/agent-events-test-json "/repo//src" "workspace_root" "/repo")
              (my/agent-events-test-json "/sshx:other:/repo" "workspace_root" "/repo")
              (my/agent-events-test-json "/repo/src" "kind" "files-changed"
                                         "workspace_root" "/repo"
                                         "changed_paths" ["src\\file"])
              (my/agent-events-test-json "/repo/src" "kind" "files-changed"
                                         "workspace_root" "/repo"
                                         "changed_paths" ["one" "two"]
                                         "observed_size" 4)
              (my/agent-events-test-json "/repo/src" "kind" "files-changed"
                                         "workspace_root" "/repo"
                                         "session_id" "unknown" "sequence" 1)))
      (should-error (my/agent-events-parse-remote invalid relay-one)
                    :type 'user-error))))

(ert-deftest my/agent-events-sequences-filter-mixed-stale-paths-without-mutation ()
  (let* ((my/agent-events-latest-sequences (make-hash-table :test 'equal))
         (event (list :source "/sshx:one:/repo/" :provider "codex"
                      :session-id "session" :workspace-root "/sshx:one:/repo/"
                      :sequence 4 :changed-paths '("stale.el" "fresh.el")))
         (stale-key (my/agent-events-sequence-key event "stale.el"))
         (fresh-key (my/agent-events-sequence-key event "fresh.el")))
    (puthash stale-key 4 my/agent-events-latest-sequences)
    (let ((accepted (my/agent-events-accept-sequence-p event)))
      (should accepted)
      (should-not (eq accepted event))
      (should (equal (plist-get event :changed-paths) '("stale.el" "fresh.el")))
      (should (equal (plist-get accepted :changed-paths) '("fresh.el")))
      (should (= (gethash stale-key my/agent-events-latest-sequences) 4))
      (should (= (gethash fresh-key my/agent-events-latest-sequences) 4)))
    (should-not (my/agent-events-accept-sequence-p event))))

(ert-deftest my/agent-events-remote-refresh-is-clean-only-and-current-state-wins ()
  (let* ((root "/sshx:one:/repo/")
         (relay (my/agent-events-test-relay "one" root "/repo"))
         (state (list :name "one" :config relay :generation 1 :active t))
         (my/agent-events-relay-states (make-hash-table :test 'equal))
         (event (list :remote t :relay "one" :route 'bound :kind "files-changed"
                      :provider "codex" :session-id "session"
                      :timestamp "2026-09-04T12:00:00Z" :title "Changed" :body ""
                      :changed-paths '("src/file.el") :observed-mtime 1 :observed-size 2))
         (attributes (list nil 1 (user-uid) 0 nil (seconds-to-time 2) nil 8
                           "-rw-------" nil 1 1)))
    (puthash "one" state my/agent-events-relay-states)
    (with-temp-buffer
      (let ((buffer (current-buffer))
            reverted)
        (set-buffer-modified-p t)
        (cl-letf (((symbol-function 'get-file-buffer)
                   (lambda (ignored-file) (ignore ignored-file) buffer))
                  ((symbol-function 'file-attributes)
                   (lambda (&rest ignored-arguments)
                     (ignore ignored-arguments)
                     (ert-fail "modified buffers must not stat remote files"))))
          (should (equal (plist-get (my/agent-events-refresh-remote (copy-tree event)) :kind)
                         "attention")))
        (set-buffer-modified-p nil)
        (cl-letf (((symbol-function 'get-file-buffer)
                   (lambda (ignored-file) (ignore ignored-file) buffer))
                  ((symbol-function 'file-attributes)
                   (lambda (&rest ignored-arguments)
                     (ignore ignored-arguments)
                     attributes))
                  ((symbol-function 'verify-visited-file-modtime)
                   (lambda (ignored-buffer) (ignore ignored-buffer) t))
                  ((symbol-function 'revert-buffer)
                   (lambda (&rest ignored-arguments)
                     (ignore ignored-arguments)
                     (ert-fail "current visited files must not revert"))))
          (let ((refreshed (my/agent-events-refresh-remote (copy-tree event))))
            (should (equal (plist-get refreshed :kind) "files-changed"))
            (should (equal (plist-get refreshed :diagnostic)
                           "Remote metadata differs: mtime, size"))
            (unwind-protect
                (with-current-buffer (my/agent-events-render refreshed)
                  (should (string-match-p
                           "diagnostic: Remote metadata differs: mtime, size"
                           (buffer-string))))
              (when (get-buffer my/agent-events-buffer-name)
                (kill-buffer my/agent-events-buffer-name)))))
        (cl-letf (((symbol-function 'get-file-buffer)
                   (lambda (ignored-file) (ignore ignored-file) buffer))
                  ((symbol-function 'file-attributes)
                   (lambda (&rest ignored-arguments)
                     (ignore ignored-arguments)
                     attributes))
                  ((symbol-function 'verify-visited-file-modtime)
                   (lambda (ignored-buffer) (ignore ignored-buffer) nil))
                  ((symbol-function 'revert-buffer)
                   (lambda (&rest arguments) (setq reverted arguments))))
          (let ((refreshed (my/agent-events-refresh-remote (copy-tree event))))
            (should (equal (plist-get refreshed :diagnostic)
                           "Remote metadata differs: mtime, size")))
          (should (equal reverted '(t t t))))
        (cl-letf (((symbol-function 'get-file-buffer)
                   (lambda (ignored-file) (ignore ignored-file) nil))
                  ((symbol-function 'file-attributes)
                   (lambda (&rest ignored-arguments)
                     (ignore ignored-arguments)
                     (ert-fail "unvisited files must not stat or open"))))
          (should (equal (plist-get (my/agent-events-refresh-remote (copy-tree event)) :kind)
                         "files-changed")))
        (cl-letf (((symbol-function 'get-file-buffer)
                   (lambda (ignored-file) (ignore ignored-file) buffer))
                  ((symbol-function 'file-attributes)
                   (lambda (&rest ignored-arguments)
                     (ignore ignored-arguments)
                     nil)))
          (should (equal (plist-get (my/agent-events-refresh-remote (copy-tree event)) :kind)
                         "attention")))))))

(ert-deftest my/agent-events-relay-configuration-lookup-and-local-identity-guards ()
  (let* ((root "/sshx:one:/repo/")
         (configuration
          (list :name "one" :workspace-root root :ssh-destination "example.test"
                :ssh-options '("-i" "/tmp/test-key")
                :remote-socket "/run/user/1000/agent-events.sock"))
         (my/agent-events-relays (list configuration))
         (my/agent-events-relay-states (make-hash-table :test 'equal))
         (my/agent-events-relay-generation 0)
         (validated (my/agent-events-relay-config "one"))
         (state (list :name "one" :config validated :generation 1 :active t))
         (temporary-file-directory "/tmp/")
         (temporary-root (make-temp-file "my-agent-events-relay-test-" t))
         (my/agent-events-relay-directory (expand-file-name "sockets/" temporary-root)))
    (unwind-protect
        (progn
          (puthash "one" state my/agent-events-relay-states)
          (should (equal (plist-get validated :workspace-root) root))
          (should (equal (my/agent-events-relay-socket-for-root root)
                         "/run/user/1000/agent-events.sock"))
          (should-not (my/agent-events-relay-socket-for-root "/sshx:one:/repo"))
          (let ((command (my/agent-events-relay-tunnel-command state)))
            (should (member "BatchMode=yes" command))
            (should (member "ConnectTimeout=10" command))
            (should (member "none" command))
            (should (member "ExitOnForwardFailure=yes" command))
            (should (member "StreamLocalBindMask=0177" command))
            (should-not (seq-some (lambda (argument)
                                    (string-match-p "StreamLocalBindUnlink" argument))
                                  command)))
          (let* ((command (my/agent-events-relay-maintenance-command
                           validated 'preflight))
                 (destination-index
                  (cl-position (plist-get validated :ssh-destination) command
                               :test #'equal))
                 (script (my/agent-events-relay-shell-script 'preflight validated)))
            (should destination-index)
            (should (= (length command) (+ destination-index 2)))
            (should (equal (nth (1+ destination-index) command)
                           (concat "sh -c " (shell-quote-argument script)))))
          (let* ((temporary-file-directory "/tmp/")
                 (command-root (make-temp-file "agent-relay-command-" t))
                 (marker (expand-file-name "quoted command marker" command-root))
                 (script (format "printf 'joined command' > %s; test -f %s"
                                 (shell-quote-argument marker)
                                 (shell-quote-argument marker))))
            (unwind-protect
                (cl-letf (((symbol-function 'my/agent-events-relay-shell-script)
                           (lambda (&rest ignored-arguments)
                             (ignore ignored-arguments)
                             script)))
                  (let* ((command (my/agent-events-relay-maintenance-command
                                   validated 'preflight))
                         (destination-index
                          (cl-position (plist-get validated :ssh-destination) command
                                       :test #'equal))
                         (joined-remote-command
                          (string-join (nthcdr (1+ destination-index) command) " ")))
                    (should (zerop (call-process "/bin/sh" nil nil nil
                                                 "-c" joined-remote-command)))
                    (should (equal (my/agent-events-test-file-text marker)
                                   "joined command"))))
              (delete-directory command-root t)))
          (let ((trace nil))
            (puthash "one" (list :name "one" :generation 0 :active t)
                     my/agent-events-relay-states)
            (cl-letf (((symbol-function 'my/agent-events-relay-stop-state)
                       (lambda (old-state)
                         (ignore old-state)
                         (push 'stop trace)))
                      ((symbol-function 'my/agent-events-relay-create-listener)
                       (lambda (new-state)
                         (push 'listener trace)
                         (plist-put new-state :listener 'listener)
                         new-state))
                      ((symbol-function 'my/agent-events-relay-run-ssh)
                       (lambda (ignored-configuration operation &optional ignored-identity)
                         (ignore ignored-configuration ignored-identity)
                         (push operation trace)
                         (if (eq operation 'postverify) "1:2" "ok")))
                      ((symbol-function 'my/agent-events-relay-start-tunnel)
                       (lambda (new-state)
                         (push 'tunnel trace)
                         (plist-put new-state :tunnel 'tunnel)
                         new-state)))
              (let ((started (my/agent-events-relay-start "one")))
                (should (plist-get started :active))
                (should (equal (nreverse trace)
                               '(stop listener preflight tunnel postverify))))))
          (setq state (my/agent-events-relay-create-listener state))
          (should (my/agent-events-relay-socket-attributes
                   (plist-get state :listener-path)))
          (delete-process (plist-get state :listener))
          (delete-file (plist-get state :listener-path))
          (with-temp-file (plist-get state :listener-path)
            (insert "replacement"))
          (my/agent-events-relay-delete-local-socket state)
          (should (file-regular-p (plist-get state :listener-path)))
          (delete-file (plist-get state :listener-path))
          (make-symbolic-link "/tmp/not-a-relay-socket" (plist-get state :listener-path))
          (my/agent-events-relay-delete-local-socket state)
          (should (file-symlink-p (plist-get state :listener-path))))
      (delete-directory temporary-root t))))

(ert-deftest my/agent-events-relay-rejects-ssh-overrides-and-unsafe-socket-paths ()
  (let* ((configuration
          (list :name "one" :workspace-root "/sshx:one:/repo/"
                :ssh-destination "example.test" :ssh-options nil
                :remote-socket "/run/user/1000/agent-events.sock"))
         (valid-socket (concat "/a/"
                               (make-string (- my/agent-events-max-unix-socket-bytes 3) ?x)))
         (too-long-socket (concat valid-socket "x")))
    (should (equal (my/agent-events-relay-name
                    (make-string my/agent-events-max-relay-name-bytes ?a))
                   (make-string my/agent-events-max-relay-name-bytes ?a)))
    (should-error
     (my/agent-events-relay-name
      (make-string (1+ my/agent-events-max-relay-name-bytes) ?a))
     :type 'user-error)
    (should (equal (my/agent-events-validate-unix-socket-path valid-socket "Test socket")
                   valid-socket))
    (should-error (my/agent-events-validate-unix-socket-path too-long-socket "Test socket")
                  :type 'user-error)
    (dolist (options
             '(("-L" "/tmp/local:/tmp/remote")
               ("-L/tmp/local:/tmp/remote")
               ("-R" "/tmp/remote:/tmp/local")
               ("-R/tmp/remote:/tmp/local")
               ("-D" "1080")
               ("-D1080")
               ("-o" "LocalForward=/tmp/local /tmp/remote")
               ("-oRemoteForward=/tmp/remote /tmp/local")
               ("-o" "DynamicForward=1080")
               ("-o" "ProxyCommand=nc %h %p")
               ("-oProxyJump=jump.example")
               ("-o" "BatchMode=no")
               ("-F" "/tmp/ssh-config")
               ("-J" "jump.example")
               ("-W" "host:22")
               ("unexpected-host")
               ("-o" "PermitLocalCommand=yes")
               ("-o" "LocalCommand=touch /tmp/unsafe")))
      (let ((invalid (copy-sequence configuration)))
        (plist-put invalid :ssh-options options)
        (should-error (my/agent-events-relay-validate-config invalid)
                      :type 'user-error)))
    (let ((invalid (copy-sequence configuration)))
      (plist-put invalid :remote-socket too-long-socket)
      (should-error (my/agent-events-relay-validate-config invalid)
                    :type 'user-error))
    (let ((invalid (copy-sequence configuration)))
      (plist-put invalid :workspace-root "/sshx:one:/repo")
      (should-error (my/agent-events-relay-validate-config invalid)
                    :type 'user-error))
    (let ((state (list :name "one" :generation 1)))
      (cl-letf (((symbol-function 'my/agent-events-relay-directory)
                 (lambda () (concat "/" (make-string 100 ?d) "/")))
                ((symbol-function 'make-network-process)
                 (lambda (&rest ignored-arguments)
                   (ignore ignored-arguments)
                   (ert-fail "Local AF_UNIX path check must precede process creation"))))
        (should-error (my/agent-events-relay-create-listener state)
                      :type 'user-error)))))

(ert-deftest my/agent-events-relay-maintenance-ssh-times-out-and-reaps ()
  (let ((configuration (my/agent-events-test-relay "one" "/sshx:one:/repo/" "/repo"))
        (my/agent-events-relay-maintenance-timeout 0.05)
        (my/agent-events-relay-termination-timeout 1)
        (make-process-function (symbol-function 'make-process))
        process
        started)
    (cl-letf (((symbol-function 'my/agent-events-relay-maintenance-command)
               (lambda (&rest ignored-arguments)
                 (ignore ignored-arguments)
                 '("/bin/sh" "-c" "exec sleep 2")))
              ((symbol-function 'make-process)
               (lambda (&rest arguments)
                 (setq process (apply make-process-function arguments)))))
      (setq started (float-time))
      (should-error (my/agent-events-relay-run-ssh configuration 'preflight)
                    :type 'user-error)
      (should (< (- (float-time) started) 1))
      (should-not (process-live-p process)))))

(ert-deftest my/agent-events-relay-tunnel-readiness-is-bounded ()
  (let ((state (list :name "one" :generation 1 :config nil))
        (my/agent-events-relay-tunnel-readiness-timeout 0.1)
        (make-process-function (symbol-function 'make-process))
        process)
    (cl-letf (((symbol-function 'my/agent-events-relay-tunnel-command)
               (lambda (ignored-state)
                 (ignore ignored-state)
                 '("/bin/sh" "-c" "exit 1")))
              ((symbol-function 'make-process)
               (lambda (&rest arguments)
                 (setq process (apply make-process-function arguments)))))
      (should-error (my/agent-events-relay-start-tunnel state) :type 'user-error)
      (should-not (process-live-p process)))))

(ert-deftest my/agent-events-relay-stop-all-is-registered-and-cleans-tracked-states ()
  (let ((my/agent-events-relay-states (make-hash-table :test 'equal))
        stopped)
    (should (memq #'my/agent-events-relay-stop-all kill-emacs-hook))
    (puthash "one" (list :name "one") my/agent-events-relay-states)
    (puthash "two" (list :name "two") my/agent-events-relay-states)
    (cl-letf (((symbol-function 'my/agent-events-relay-stop-state)
               (lambda (state &optional skip-remote-cleanup)
                 (should-not skip-remote-cleanup)
                 (push (plist-get state :name) stopped))))
      (should-not (my/agent-events-relay-stop-all)))
    (should (equal (sort stopped #'string<) '("one" "two")))))

(ert-deftest my/agent-events-relay-tunnel-exit-cleans-without-reconnecting ()
  (let* ((my/agent-events-relay-states (make-hash-table :test 'equal))
         (state (list :name "one" :generation 1 :active t))
         (process (make-process :name "my-agent-events-test-tunnel-exit"
                                :command '("/bin/sh" "-c" "exit 1")
                                :connection-type 'pipe :noquery t))
         stopped)
    (unwind-protect
        (progn
          (process-put process 'my/agent-events-relay-name "one")
          (process-put process 'my/agent-events-relay-generation 1)
          (puthash "one" state my/agent-events-relay-states)
          (accept-process-output process 0.2)
          (cl-letf (((symbol-function 'my/agent-events-relay-stop-state)
                     (lambda (stopped-state &optional skip-remote-cleanup)
                       (setq stopped (list stopped-state skip-remote-cleanup)))))
            (my/agent-events-relay-tunnel-sentinel process "finished\n"))
          (should-not (plist-get state :active))
          (should (eq (car stopped) state))
          (should (cadr stopped)))
      (when (process-live-p process)
        (delete-process process)))))

(ert-deftest my/agent-events-listener-enforces-one-bounded-frame-and-deadline ()
  (let* ((root "/sshx:one:/repo/")
         (relay (my/agent-events-test-relay "one" root "/repo"))
         (my/agent-events-relay-states (make-hash-table :test 'equal))
         (temporary-file-directory "/tmp/")
         (temporary-root (make-temp-file "my-agent-events-listener-test-" t))
         (my/agent-events-relay-directory (expand-file-name "sockets/" temporary-root))
         (state (list :name "one" :config relay :generation 1 :active t
                      :clients nil :pending 0))
         timers)
    (unwind-protect
        (progn
          (setq state (my/agent-events-relay-create-listener state))
          (my/agent-events-relay-state-put state)
          (cl-letf (((symbol-function 'run-at-time)
                     (lambda (&rest arguments)
                       (push arguments timers)
                       'relay-test-timer)))
            (let* ((server-client (my/agent-events-test-listener-client state))
                   (payload (concat "{\"body\":\""
                                    (make-string (- my/agent-events-max-raw-bytes 11) ?x)
                                    "\"}")))
              (should (= (string-bytes payload) my/agent-events-max-raw-bytes))
              (my/agent-events-relay-client-filter
               server-client (encode-coding-string (substring (concat payload "\n") 0 31)
                                                  'binary))
              (my/agent-events-relay-client-filter
               server-client (encode-coding-string (substring (concat payload "\n") 31)
                                                  'binary))
              (should (seq-some (lambda (timer)
                                  (and (eq (nth 2 timer)
                                           #'my/agent-events-relay-deferred-process)
                                       (equal (nth 5 timer) payload)))
                                timers)))
            (let ((server-client (my/agent-events-test-listener-client state)))
              (my/agent-events-relay-client-filter
               server-client (encode-coding-string "{\"incomplete\"" 'binary))
              (let ((deadline
                     (seq-find (lambda (timer)
                                 (eq (nth 2 timer)
                                     #'my/agent-events-relay-client-deadline))
                               timers)))
                (should deadline)
                (funcall (nth 2 deadline) (nth 3 deadline))
                (should (process-get (nth 3 deadline)
                                     'my/agent-events-relay-closed))))
            (let ((server-client (my/agent-events-test-listener-client state)))
              (my/agent-events-relay-client-filter
               server-client
               (encode-coding-string
                (make-string (1+ my/agent-events-max-raw-bytes) ?x) 'binary))
              (should (process-get server-client 'my/agent-events-relay-closed)))
            (let ((server-client (my/agent-events-test-listener-client state)))
              (my/agent-events-relay-client-filter server-client (unibyte-string 255 10))
              (should (process-get server-client 'my/agent-events-relay-closed)))
            (let ((server-client (my/agent-events-test-listener-client state)))
              (my/agent-events-relay-client-filter
               server-client (encode-coding-string "{}\n{}\n" 'binary))
              (should (process-get server-client 'my/agent-events-relay-closed)))
            (setf (plist-get state :pending) my/agent-events-listener-max-pending)
            (let ((server-client (my/agent-events-test-listener-client state)))
              (my/agent-events-relay-client-filter
               server-client (encode-coding-string "{}\n" 'binary))
              (should (process-get server-client 'my/agent-events-relay-closed)))
            (setf (plist-get state :pending) 0)
            (setf (plist-get state :clients) (make-list my/agent-events-listener-max-clients 'held))
            (should-not (my/agent-events-test-listener-client state t))
            (should (= (length (plist-get state :clients))
                       my/agent-events-listener-max-clients))
            (setf (plist-get state :clients) nil)))
      (my/agent-events-relay-stop-state state)
      (delete-directory temporary-root t))))

(provide 'my-agent-events-test)

;;; my-agent-events-test.el ends here
