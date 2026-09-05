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

(provide 'my-agent-events-test)

;;; my-agent-events-test.el ends here
