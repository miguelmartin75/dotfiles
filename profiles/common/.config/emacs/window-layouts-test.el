;;; window-layouts-test.el --- Behavior tests for task workspace layouts -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'ert)

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'my-window-layouts)

(defmacro my/layout-test-with-tabs (&rest body)
  "Run BODY with the public Phase 1 tab-bar property model."
  (declare (indent 0) (debug t))
  `(let ((tabs (list '(current-tab (name . "first")))))
     (cl-letf
         (((symbol-function 'tab-bar-tabs)
           (lambda (&optional _frame) tabs))
          ((symbol-function 'tab-bar-tabs-set)
           (lambda (new-tabs &optional _frame) (setq tabs new-tabs)))
          ((symbol-function 'tab-bar-new-tab)
           (lambda (&optional _frame)
             (setq tabs
                   (append
                    (mapcar (lambda (tab)
                              (cons (if (eq (car tab) 'current-tab) 'tab (car tab))
                                    (cdr tab)))
                            tabs)
                    (list '(current-tab (name . "new"))))))
          ((symbol-function 'tab-bar-select-tab)
           (lambda (index &optional _frame)
             (setq tabs
                   (cl-loop for tab in tabs
                            for tab-index from 1
                            collect (cons (if (= index tab-index) 'current-tab 'tab)
                                          (cdr tab))))))
          ((symbol-function 'tab-bar-rename-tab)
           (lambda (name &optional _all)
             (my/tab-set-current-property 'name name)))))
       ,@body)))

(defmacro my/layout-test-with-window (&rest body)
  "Run BODY in one restored ordinary window."
  (declare (indent 0) (debug t))
  `(save-window-excursion
     (delete-other-windows)
     ,@body))

(defun my/layout-test-buffer (name directory)
  "Create a live ordinary buffer named NAME rooted at DIRECTORY."
  (let ((buffer (generate-new-buffer name)))
    (with-current-buffer buffer
      (setq default-directory directory))
    buffer))

(defun my/layout-test-window-buffers ()
  "Return the ordinary visible buffers in window order."
  (mapcar #'window-buffer (window-list nil 'no-minibuf)))

(ert-deftest my/layout-renderer-is-transactional-idempotent-and-tab-local ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((root-one "/tmp/layout-one/")
             (root-two "/tmp/layout-two/")
             (edit-one (my/layout-test-buffer " *layout-edit-one*" root-one))
             (edit-one-replacement
              (my/layout-test-buffer " *layout-edit-one-replacement*" root-one))
             (edit-two (my/layout-test-buffer " *layout-edit-two*" root-two))
             (special (my/layout-test-buffer " *layout-special*" root-one))
             (companion-one (my/layout-test-buffer " *layout-companion-one*" root-one))
             (companion-two (my/layout-test-buffer " *layout-companion-two*" root-two))
             (calls 0)
             (my/window-layouts
              '((focus :key "e" :label "Focus edit")
                (terminal :key "T" :label "Terminal"
                          :buffer-function my/layout-test-terminal-provider)
                (broken :key "B" :label "Broken"
                        :buffer-function my/layout-test-broken-provider))))
        (unwind-protect
            (cl-letf (((symbol-function 'my/layout-test-terminal-provider)
                       (lambda (_entry _force)
                         (setq calls (1+ calls))
                         (if (= calls 1) companion-one companion-two)))
                      ((symbol-function 'my/layout-test-broken-provider)
                       (lambda (_entry _force)
                         (user-error "provider failed"))))
              (switch-to-buffer edit-one)
              (with-current-buffer special
                (special-mode))
              (my/tab-set-current-property 'my/workspace-root root-one)
              (my/tab-set-current-property 'my/layout-edit-buffer edit-one)
              (my/layout-apply 'terminal)
              (should (= (length (window-list nil 'no-minibuf)) 2))
              (should (eq (window-parameter (selected-window) 'my/layout-role) 'edit))
              (should (eq (window-parameter
                           (seq-find (lambda (window)
                                       (eq (window-parameter window 'my/layout-role)
                                           'companion))
                                     (window-list nil 'no-minibuf))
                           'my/layout-role)
                          'companion))
              (should (eq (my/tab-current-property 'my/layout-edit-buffer) edit-one))
              (switch-to-buffer edit-one-replacement)
              (my/layout-apply 'terminal)
              (should (eq (my/tab-current-property 'my/layout-edit-buffer)
                          edit-one-replacement))
              (switch-to-buffer edit-two)
              (my/layout-apply 'terminal)
              (should (eq (my/tab-current-property 'my/layout-edit-buffer)
                          edit-one-replacement))
              (switch-to-buffer special)
              (my/layout-apply 'terminal)
              (should (eq (my/tab-current-property 'my/layout-edit-buffer)
                          edit-one-replacement))
              (my/layout-apply 'terminal)
              (should (= (length (window-list nil 'no-minibuf)) 2))
              (should (= calls 5))
              (let ((buffers (my/layout-test-window-buffers))
                    (cache (my/tab-current-property 'my/layout-companion-buffers)))
                (should-error (my/layout-apply 'broken) :type 'user-error)
                (should (equal (my/layout-test-window-buffers) buffers))
                (should (equal (my/tab-current-property 'my/layout-companion-buffers) cache)))
              (my/workspace-select-or-create-tab root-two)
              (switch-to-buffer edit-two)
              (my/tab-set-current-property 'my/layout-edit-buffer edit-two)
              (my/layout-apply 'focus)
              (should (= (length (window-list nil 'no-minibuf)) 1))
              (should (eq (my/tab-current-property 'my/layout-edit-buffer) edit-two))
              (my/workspace-select-or-create-tab root-one)
              (should (eq (my/tab-current-property 'my/layout-edit-buffer)
                          edit-one-replacement)))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit-one edit-one-replacement edit-two special
                      companion-one companion-two)))))))

(ert-deftest my/layout-roleless-special-buffer-cannot-replace-primary-edit ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((temporary-root (make-temp-file "my-layout-roleless-" t))
             (root (file-name-as-directory temporary-root))
             (edit (my/layout-test-buffer " *roleless-edit*" root))
             (special (my/layout-test-buffer " *roleless-special*" root))
             (dired (dired-noselect root)))
        (unwind-protect
            (progn
              (with-current-buffer special
                (special-mode))
              (switch-to-buffer edit)
              (my/tab-set-current-property 'my/workspace-root root)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (switch-to-buffer special)
              (set-window-parameter (selected-window) 'my/layout-role nil)
              (should (eq (my/layout-edit-buffer root) edit))
              (switch-to-buffer dired)
              (set-window-parameter (selected-window) 'my/layout-role nil)
              (should (eq (my/layout-edit-buffer root) dired)))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit special dired))
          (delete-directory temporary-root t))))))

(ert-deftest my/layout-agent-zmx-descriptors-validate-reuse-and-synchronize-send-target ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((root-one "/tmp/same-name/one/")
             (root-two "/tmp/same-name/two/")
             (edit (my/layout-test-buffer " *agent-edit*" root-one))
             (agent (my/layout-test-buffer " *agent-session*" root-one))
             (target (list :name "agent" :directory root-one :cwd root-one
                           :where "local" :session "metadata"))
             (my/window-layouts
              '((agent :key "A" :label "Agent"
                       :buffer-function my/layout-agent-buffer
                       :session nil))))
        (unwind-protect
            (cl-letf (((symbol-function 'term-sessions-read-existing-session-entry)
                       (lambda (_prompt) target))
                      ((symbol-function 'term-sessions-open-with-frontend)
                       (lambda (entry command frontend allow-create)
                         (should (equal (plist-get entry :where) "local"))
                         (should-not command)
                         (should (eq frontend 'ghostel))
                         (should-not allow-create)
                         agent)))
              (switch-to-buffer edit)
              (my/tab-set-current-property 'my/workspace-root root-one)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (my/layout-apply 'agent)
              (let ((saved (my/tab-current-property 'my/layout-agent-target)))
                (should (equal (plist-get saved :where) "local"))
                (should (eq (plist-get saved :type) 'zmx))
                (should (equal (my/tab-current-property 'my/send-text-last-target) saved)))
              (should-error
               (my/layout-validate-target-root
                (list :name "agent" :directory root-one :cwd "/tmp/other/")
                root-one nil)
               :type 'user-error)
              (should
               (my/layout-validate-target-root
                (list :name "shared" :directory root-one :cwd "/tmp/other/")
                root-one t))
              (should-not (equal (my/layout-session-name root-one 'agent)
                                 (my/layout-session-name root-two 'agent))))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit agent)))))))

(ert-deftest my/layout-literal-agent-session-cache-must-match-its-configured-name ()
  (my/layout-test-with-tabs
    (let* ((root "/tmp/layout-literal-agent/")
           (created (my/layout-test-buffer " *literal-agent-created*" root))
           (attached (my/layout-test-buffer " *literal-agent-attached*" root))
           (entry '(:session "configured-agent" :command ("codex")))
           (mismatched '(:type zmx :name "other-agent" :directory "/tmp/layout-literal-agent/"
                                  :cwd "/tmp/layout-literal-agent/"))
           (matching '(:type zmx :name "configured-agent" :directory "/tmp/layout-literal-agent/"
                                :cwd "/tmp/layout-literal-agent/" :where "local"))
           (task (list :id "task-a" :root root))
           opened created-command attached-target)
      (unwind-protect
          (cl-letf (((symbol-function 'my/workflow-current-task)
                     (lambda () task))
                    ((symbol-function 'term-sessions-open)
                     (lambda (target command)
                       (setq opened target
                             created-command command)
                       created))
                    ((symbol-function 'term-sessions-open-with-frontend)
                     (lambda (target command frontend allow-create)
                       (setq attached-target target)
                       (should-not command)
                       (should (eq frontend 'ghostel))
                       (should-not allow-create)
                       attached)))
            (my/tab-set-current-property 'my/workspace-root root)
            (my/tab-set-current-property 'my/layout-agent-target mismatched)
            (my/layout-terminal-agent-buffer entry nil)
            (should (equal (plist-get opened :name) "configured-agent"))
            (should (string-match-p "task-a" created-command))
            (should (string-match-p "codex" created-command))
            (my/tab-set-current-property 'my/layout-agent-target matching)
            (my/tab-set-current-property 'my/layout-agent-task-id "task-a")
            (my/tab-set-current-property 'my/layout-companion-buffers nil)
            (my/layout-terminal-agent-buffer entry nil)
            (should (equal attached-target matching))
            (setq task (list :id "task-b" :root root))
            (my/tab-set-current-property 'my/layout-companion-buffers nil)
            (should-error (my/layout-terminal-agent-buffer entry nil)
                          :type 'user-error))
        (mapc (lambda (buffer)
                (when (buffer-live-p buffer)
                  (kill-buffer buffer)))
              (list created attached))))))

(ert-deftest my/layout-authoritative-task-rebinding-replaces-task-specific-companions ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((root "/tmp/layout-task-rebinding/")
             (edit (my/layout-test-buffer " *task-rebinding-edit*" root))
             (old-agent (my/layout-test-buffer " *task-rebinding-old-agent*" root))
             (new-agent (my/layout-test-buffer " *task-rebinding-new-agent*" root))
             (old-gptel (my/layout-test-buffer " *task-rebinding-old-gptel*" root))
             (new-gptel (my/layout-test-buffer " *task-rebinding-new-gptel*" root))
             (old-native (my/layout-test-buffer " *task-rebinding-old-native*" root))
             (new-native (my/layout-test-buffer " *task-rebinding-new-native*" root))
             (task (list :id "old-task" :root root))
             launches gptel-name)
        (unwind-protect
            (cl-letf (((symbol-function 'my/workflow-current-task)
                       (lambda () task))
                      ((symbol-function 'term-sessions-open)
                       (lambda (target command)
                         (push (list target command) launches)
                         (if (equal (plist-get task :id) "old-task") old-agent new-agent)))
                      ((symbol-function 'term-sessions-open-with-frontend)
                       (lambda (&rest _arguments)
                         (error "A rebound automatic agent must not attach the old session")))
                      ((symbol-function 'gptel)
                       (lambda (name &rest _arguments)
                         (setq gptel-name name)
                         new-gptel)))
              (switch-to-buffer edit)
              (my/tab-set-current-property 'my/workspace-root root)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (let ((my/layout-codex-native-launcher nil))
                (my/layout-apply 'agent)
                (let ((old-target (my/tab-current-property 'my/layout-agent-target)))
                  (setq task (list :id "new-task" :root root))
                  (my/layout-apply 'agent)
                  (should (buffer-live-p old-agent))
                  (should (eq (my/layout-cached-companion 'agent) new-agent))
                  (should-not (equal (plist-get old-target :name)
                                     (plist-get (my/tab-current-property
                                                 'my/layout-agent-target)
                                                :name)))
                  (should (equal (my/tab-current-property 'my/layout-agent-task-id)
                                 "new-task"))
                  (should (= (length launches) 2))
                  (should (string-match-p "old-task"
                                          (cadr (cadr launches))))
                  (should (string-match-p "new-task"
                                          (cadr (car launches))))))
              (my/tab-set-current-property
               'my/layout-companion-buffers
               `((agent . ,old-native) (gptel . ,old-gptel)))
              (my/tab-set-current-property 'my/layout-agent-backend 'codex-native)
              (my/tab-set-current-property 'my/layout-agent-task-id "old-task")
              (my/tab-set-current-property 'my/layout-gptel-task-id "old-task")
              (let ((my/layout-codex-native-launcher
                     (lambda (_root _task) new-native)))
                (should (eq (my/layout-native-agent-buffer root task nil) new-native)))
              (should (eq (my/layout-gptel-buffer '(:buffer nil) nil) new-gptel))
              (should (string-match-p "gptel:" gptel-name)))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit old-agent new-agent old-gptel new-gptel
                      old-native new-native)))))))

(ert-deftest my/layout-zmx-terminal-cache-validates-root-and-reattaches-dead-frontends ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((root "/tmp/layout-zmx-terminal/")
             (edit (my/layout-test-buffer " *zmx-terminal-edit*" root))
             (terminal (my/layout-test-buffer " *zmx-terminal*" root))
             (reattached (my/layout-test-buffer " *zmx-terminal-reattached*" root))
             (target (list :name "terminal" :directory root :cwd root))
             (selector-calls 0)
             (open-calls 0)
             opened-targets
             (my/window-layouts
              '((terminal :key "T" :label "Terminal"
                          :buffer-function my/layout-terminal-buffer
                          :provider existing-zmx))))
        (unwind-protect
            (cl-letf (((symbol-function 'term-sessions-read-existing-session-entry)
                       (lambda (_prompt)
                         (setq selector-calls (1+ selector-calls))
                         target))
                      ((symbol-function 'term-sessions-open-with-frontend)
                       (lambda (entry command frontend allow-create)
                         (setq open-calls (1+ open-calls))
                         (push entry opened-targets)
                         (should (eq (plist-get entry :type) 'zmx))
                         (should-not command)
                         (should (eq frontend 'ghostel))
                         (should-not allow-create)
                         (if (= open-calls 1) terminal reattached))))
              (switch-to-buffer edit)
              (my/tab-set-current-property 'my/workspace-root root)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (my/layout-apply 'terminal)
              (let ((saved (my/tab-current-property 'my/layout-terminal-target)))
                (should (my/layout-zmx-target-p saved))
                (should (= selector-calls 1))
                (should (= open-calls 1))
                (kill-buffer terminal)
                (my/layout-apply 'terminal)
                (should (= selector-calls 1))
                (should (= open-calls 2))
                (should (eq (car opened-targets) saved))
                (should (eq (my/layout-cached-companion 'terminal) reattached))
                (my/send-text-save-last-target
                 '(:type zmx :name "another-target" :directory "/tmp/"))
                (my/layout-apply 'terminal)
                (should (= selector-calls 1))
                (should (= open-calls 2))
                (should (equal (my/tab-current-property
                                'my/layout-terminal-target)
                               saved))
                (should (equal (my/tab-current-property
                                'my/send-text-last-target)
                               saved))
                (my/tab-set-current-property
                 'my/layout-terminal-target
                 '(:type zmx :name "stale" :directory "/tmp/other/" :cwd "/tmp/other/"))
                (my/layout-apply 'terminal)
                (should (= selector-calls 2))
                (should (= open-calls 3))
                (my/tab-set-current-property
                 'my/layout-terminal-target '(:type zmx :name ""))
                (my/layout-apply 'terminal)
                (should (= selector-calls 3))
                (should (= open-calls 4))))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit terminal reattached)))))))

(ert-deftest my/layout-terminal-agent-fallback-replaces-cached-native-companion ()
  (my/layout-test-with-tabs
    (let* ((root "/tmp/layout-agent-fallback/")
           (native (my/layout-test-buffer " *cached-native-agent*" root))
           (terminal (my/layout-test-buffer " *fallback-terminal-agent*" root))
           (target (list :type 'zmx :name "agent" :directory root :cwd root))
           (entry '(:session my/layout-agent-session-name :command ("codex")))
           (open-calls 0))
      (unwind-protect
          (cl-letf (((symbol-function 'term-sessions-open-with-frontend)
                     (lambda (opened-target command frontend allow-create)
                       (setq open-calls (1+ open-calls))
                       (should (equal opened-target target))
                       (should-not command)
                       (should (eq frontend 'ghostel))
                       (should-not allow-create)
                       terminal)))
            (my/tab-set-current-property 'my/workspace-root root)
            (my/tab-set-current-property 'my/layout-companion-buffers
                                         `((agent . ,native)))
            (my/tab-set-current-property 'my/layout-agent-backend 'codex-native)
            (my/tab-set-current-property 'my/layout-agent-target target)
            (let ((my/layout-codex-native-launcher nil))
              (should (eq (my/layout-agent-buffer entry nil) terminal)))
            (should (= open-calls 1))
            (should (eq my/layout-provider-agent-backend 'terminal-agent))
            (should (equal my/layout-provider-agent-target target)))
        (mapc (lambda (buffer)
                (when (buffer-live-p buffer)
                  (kill-buffer buffer)))
              (list native terminal))))))

(ert-deftest my/layout-ghostel-terminal-targets-reuse-and-synchronize-send-target ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((temporary-root (make-temp-file "my-layout-ghostel-" t))
             (root (file-name-as-directory temporary-root))
             (edit (my/layout-test-buffer " *ghostel-edit*" root))
            buffers processes)
        (unwind-protect
            (progn
              (switch-to-buffer edit)
              (my/tab-set-current-property 'my/workspace-root root)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (dolist (provider '(project-ghostel folder-ghostel))
                (let* ((initial (generate-new-buffer
                                 (format " *%s-initial*" provider)))
                       (replacement (generate-new-buffer
                                     (format " *%s-replacement*" provider)))
                       (initial-process
                        (start-process (format "%s-initial" provider) initial "cat"))
                       (replacement-process
                        (start-process (format "%s-replacement" provider) replacement "cat"))
                       (calls 0)
                       selected-provider
                       (my/window-layouts
                        `((terminal :key "T" :label "Terminal"
                                    :buffer-function my/layout-terminal-buffer
                                    :provider ,provider))))
                  (setq buffers (append buffers (list initial replacement))
                        processes (append processes
                                          (list initial-process replacement-process)))
                  (my/tab-set-current-property 'my/layout-companion-buffers nil)
                  (my/tab-set-current-property 'my/layout-terminal-target nil)
                  (my/tab-set-current-property 'my/send-text-last-target nil)
                  (cl-letf (((symbol-function 'my/layout-project-p)
                             (lambda (_root) (eq provider 'project-ghostel)))
                            ((symbol-function 'ghostel-buffer-list)
                             (lambda () (list initial replacement)))
                            ((symbol-function 'ghostel-project)
                             (lambda ()
                               (setq selected-provider 'project-ghostel
                                     calls (1+ calls))
                               (if (= calls 1) initial replacement)))
                            ((symbol-function 'ghostel-create)
                             (lambda (&rest _arguments)
                               (setq selected-provider 'folder-ghostel
                                     calls (1+ calls))
                               (if (= calls 1) initial replacement))))
                    (my/layout-apply 'terminal)
                    (let ((target (my/tab-current-property 'my/layout-terminal-target)))
                      (should (eq selected-provider provider))
                      (should (eq (plist-get target :type) 'ghostel))
                      (should (eq (plist-get target :buffer) initial))
                      (should (eq (plist-get target :process) initial-process))
                      (should (equal (my/tab-current-property
                                      'my/send-text-last-target)
                                     target)))
                    (my/layout-apply 'terminal)
                    (should (= calls 1))
                    (delete-process initial-process)
                    (my/layout-apply 'terminal)
                    (let ((target (my/tab-current-property 'my/layout-terminal-target)))
                      (should (= calls 2))
                      (should (eq (plist-get target :buffer) replacement))
                      (should (eq (plist-get target :process) replacement-process))
                      (should (equal (my/tab-current-property
                                      'my/send-text-last-target)
                                     target)))))))
          (mapc (lambda (process)
                  (when (process-live-p process)
                    (delete-process process)))
                processes)
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (cons edit buffers))
          (delete-directory temporary-root t))))))

(ert-deftest my/layout-agent-capability-routing-never-probes-native-over-tramp ()
  (my/layout-test-with-tabs
    (let* ((local-root "/tmp/layout-native/")
           (remote-root "/ssh:layout-host:/srv/work/")
           (local-task (list :id "native-task" :root local-root))
           (terminal (my/layout-test-buffer " *terminal-agent*" local-root))
           (native (my/layout-test-buffer " *native-agent*" local-root))
           (my/window-layouts
            '((agent :key "A" :label "Agent"
                     :buffer-function my/layout-agent-buffer
                     :session my/layout-agent-session-name
                     :command ("codex"))))
           launcher-called launcher-task executable-probed)
      (unwind-protect
          (cl-letf (((symbol-function 'my/layout-terminal-agent-buffer)
                     (lambda (_entry _force)
                       (setq my/layout-provider-agent-target
                             (list :type 'zmx :name "agent" :directory local-root
                                   :cwd local-root)
                             my/layout-provider-agent-backend 'terminal-agent)
                       terminal))
                    ((symbol-function 'my/workflow-current-task)
                     (lambda () local-task)))
            (my/tab-set-current-property 'my/workspace-root local-root)
            (let ((my/layout-codex-native-launcher nil))
              (should (eq (my/layout-agent-buffer (my/layout-entry 'agent) nil) terminal)))
            (let ((my/layout-codex-native-launcher
                   (lambda (_root task)
                     (setq launcher-called t)
                     (setq launcher-task task)
                     native)))
              (cl-letf (((symbol-function 'executable-find)
                         (lambda (_program) "/usr/local/bin/codex")))
                (should (eq (my/layout-agent-buffer (my/layout-entry 'agent) t) native))
                (should launcher-called)
                (should (eq launcher-task local-task))
                (should (eq my/layout-provider-agent-backend 'codex-native))
                (my/tab-set-current-property
                 'my/send-text-last-target
                 '(:type zmx :name "existing-terminal" :directory "/tmp/"))
                (my/tab-set-current-property
                 'my/layout-agent-target
                 '(:type zmx :name "old-agent" :directory "/tmp/"))
                (let ((my/layout-provider-terminal-target nil)
                      (my/layout-provider-agent-target my/layout-clear-target)
                      (my/layout-provider-agent-backend 'codex-native))
                  (my/layout-commit 'agent local-root nil terminal native))
                (should-not (my/tab-current-property 'my/layout-agent-target))
                (should (equal (plist-get (my/tab-current-property
                                            'my/send-text-last-target)
                                          :name)
                               "existing-terminal"))))
            (let ((my/layout-codex-native-launcher
                   (lambda (_root _task)
                     (user-error "native startup failed"))))
              (cl-letf (((symbol-function 'executable-find)
                         (lambda (_program) "/usr/local/bin/codex")))
                (should (eq (my/layout-agent-buffer (my/layout-entry 'agent) t) terminal))
                (should (eq my/layout-provider-agent-backend 'terminal-agent))))
            (my/tab-set-current-property 'my/workspace-root remote-root)
            (should (equal (my/layout-root) remote-root))
            (should (file-remote-p (my/layout-root)))
            (let ((my/layout-codex-native-launcher
                   (lambda (&rest _arguments)
                     (setq launcher-called 'tramp)
                     native)))
              (cl-letf (((symbol-function 'executable-find)
                         (lambda (&rest _arguments)
                           (setq executable-probed t)
                           (error "must not probe native executable over TRAMP"))))
                (should (eq (my/layout-agent-buffer (my/layout-entry 'agent) t) terminal))
                (should-not executable-probed)
                (should-not (eq launcher-called 'tramp)))))
        (mapc (lambda (buffer)
                (when (buffer-live-p buffer)
                  (kill-buffer buffer)))
              (list terminal native))))))

(ert-deftest my/layout-agent-command-quotes-only-root-verified-environment ()
  (my/layout-test-with-tabs
    (let ((task nil)
          (relay-socket "/run/user/1000/emacs-agent-event.sock")
          relay-roots
          (entry '(:command ("codex" "--model" "name with spaces"))))
      (cl-letf (((symbol-function 'my/workflow-current-task)
                 (lambda ()
                   (or task
                       (user-error "The current tab has no active work task"))))
                ((symbol-function 'my/agent-events-relay-socket-for-root)
                 (lambda (root)
                   (push root relay-roots)
                   relay-socket)))
        (setq task (list :id "task id" :root "/tmp/work space/"))
        (should
         (equal
          (my/layout-agent-command entry "/tmp/work space/")
          (mapconcat #'shell-quote-argument
                     '("env" "EMACS_WORK_TASK_ID=task id"
                       "EMACS_WORKSPACE_ROOT=/tmp/work space/"
                       "codex" "--model" "name with spaces")
                     " ")))
        (should-not relay-roots)
        (setq task (list :id "task id" :root "/ssh:host:/srv/work/"))
        (should
         (equal
          (my/layout-agent-command entry "/ssh:host:/srv/work/")
          (mapconcat #'shell-quote-argument
                     '("env" "EMACS_WORK_TASK_ID=task id"
                       "EMACS_WORKSPACE_ROOT=/srv/work"
                       "EMACS_AGENT_EVENT_SOCKET=/run/user/1000/emacs-agent-event.sock"
                       "codex" "--model" "name with spaces")
                     " ")))
        (setq task nil)
        (should
         (equal
          (my/layout-agent-command entry "/ssh:host:/srv/work/")
          (mapconcat #'shell-quote-argument
                     '("env" "EMACS_AGENT_EVENT_SOCKET=/run/user/1000/emacs-agent-event.sock"
                       "codex" "--model" "name with spaces")
                     " ")))
        (setq relay-socket nil)
        (should
         (equal
          (my/layout-agent-command entry "/ssh:host:/srv/work/")
          (mapconcat #'shell-quote-argument
                     '("codex" "--model" "name with spaces")
                     " ")))
        (setq task (list :id "root task" :root "/ssh:host:/"))
        (should
         (equal
          (my/layout-agent-command entry "/ssh:host:/")
          (mapconcat #'shell-quote-argument
                     '("env" "EMACS_WORK_TASK_ID=root task"
                       "EMACS_WORKSPACE_ROOT=/"
                       "codex" "--model" "name with spaces")
                     " ")))
        (setq task (list :id "stale task" :root "/tmp/other-workspace/"))
        (should
         (equal
          (my/layout-agent-command entry "/tmp/work space/")
          (mapconcat #'shell-quote-argument
                     '("codex" "--model" "name with spaces")
                     " ")))
        (should (equal (nreverse relay-roots)
                       '("/ssh:host:/srv/work/" "/ssh:host:/srv/work/"
                         "/ssh:host:/srv/work/" "/ssh:host:/")))))))

(ert-deftest my/layout-agent-command-remote-fallback-without-relay-lookup ()
  (my/layout-test-with-tabs
    (let ((entry '(:command ("codex")))
          (normal-fboundp (symbol-function 'fboundp)))
      (cl-letf (((symbol-function 'my/workflow-current-task)
                 (lambda ()
                   (user-error "The current tab has no active work task")))
                ((symbol-function 'fboundp)
                 (lambda (symbol)
                   (if (eq symbol 'my/agent-events-relay-socket-for-root)
                       nil
                     (funcall normal-fboundp symbol)))))
        (should
         (equal (my/layout-agent-command entry "/ssh:host:/srv/work/")
                (shell-quote-argument "codex")))))))

(ert-deftest my/layout-gptel-and-magit-use-root-context-and-preserve-failure-view ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((root "/tmp/layout-repository/")
             (edit (my/layout-test-buffer " *provider-edit*" root))
             (gptel-buffer (my/layout-test-buffer " *provider-gptel*" root))
             (magit-buffer (my/layout-test-buffer " *provider-magit*" root))
             gptel-directory gptel-name gptel-arguments magit-directory magit-root
             (my/window-layouts
              '((gptel :key "G" :label "Gptel"
                       :buffer-function my/layout-gptel-buffer :buffer "*conversation*")
                (magit :key "M" :label "Magit"
                       :buffer-function my/layout-magit-buffer))))
        (unwind-protect
            (cl-letf (((symbol-function 'gptel)
                      (lambda (name &rest arguments)
                         (setq gptel-directory default-directory
                               gptel-name name
                               gptel-arguments arguments)
                         gptel-buffer))
                      ((symbol-function 'process-file)
                       (lambda (&rest _arguments) 0))
                      ((symbol-function 'magit-status-setup-buffer)
                       (lambda (directory &rest _arguments)
                         (setq magit-directory default-directory
                               magit-root directory)
                         magit-buffer)))
              (switch-to-buffer edit)
              (insert "selection")
              (my/tab-set-current-property 'my/workspace-root root)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (let ((transient-mark-mode t))
                (set-mark (point-min))
                (goto-char (point-max))
                (activate-mark)
                (my/layout-apply 'gptel)
                (should (equal gptel-directory root))
                (should (equal gptel-name "*conversation*"))
                (should-not gptel-arguments)
                (should (use-region-p))
                (deactivate-mark))
              (my/layout-apply 'magit)
              (should (equal magit-directory root))
              (should (equal magit-root root))
              (let ((buffers (my/layout-test-window-buffers)))
                (cl-letf (((symbol-function 'process-file)
                           (lambda (&rest _arguments) 1)))
                  (should-error (my/layout-apply 'magit) :type 'user-error))
                (should (equal (my/layout-test-window-buffers) buffers))))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit gptel-buffer magit-buffer)))))))

(ert-deftest my/workspace-select-defaults-from-the-correct-live-buffer ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((temporary-root (make-temp-file "my-layout-workspace-" t))
             (root-one (file-name-as-directory (expand-file-name "one" temporary-root)))
             (root-two (file-name-as-directory (expand-file-name "two" temporary-root)))
             (edit (my/layout-test-buffer " *workspace-edit*" root-one))
             (companion (my/layout-test-buffer " *workspace-companion*" root-two))
             prompt-directory)
        (make-directory root-one t)
        (make-directory root-two t)
        (unwind-protect
            (progn
              (switch-to-buffer edit)
              (my/tab-set-current-property 'my/workspace-root root-one)
              (my/tab-set-current-property 'my/layout-edit-buffer edit)
              (switch-to-buffer companion)
              (set-window-parameter (selected-window) 'my/layout-role 'companion)
              (cl-letf (((symbol-function 'project-prompt-project-dir)
                         (lambda (&rest _arguments)
                           (setq prompt-directory default-directory)
                           root-one)))
                (my/workspace-select))
              (should (equal prompt-directory root-one))
              (set-window-parameter (selected-window) 'my/layout-role nil)
              (cl-letf (((symbol-function 'project-prompt-project-dir)
                         (lambda (&rest _arguments)
                           (setq prompt-directory default-directory)
                           root-one)))
                (my/workspace-select))
              (should (equal prompt-directory root-two)))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (list edit companion))
          (delete-directory temporary-root t))))))

(ert-deftest my/workspace-select-creates-isolates-and-rebinds-layout-state-atomically ()
  (my/layout-test-with-tabs
    (my/layout-test-with-window
      (let* ((temporary-root (make-temp-file "my-layout-workspace-" t))
             (root-one (file-name-as-directory (expand-file-name "one" temporary-root)))
             (root-two (file-name-as-directory (expand-file-name "two" temporary-root)))
             (root-three (file-name-as-directory (expand-file-name "three" temporary-root)))
             (root-four (file-name-as-directory (expand-file-name "four" temporary-root)))
             (source (my/layout-test-buffer " *workspace-source*" root-one))
             root-two-edit)
        (make-directory root-one t)
        (make-directory root-two t)
        (make-directory root-three t)
        (make-directory root-four t)
        (unwind-protect
            (progn
              (switch-to-buffer source)
              (my/workspace-select root-two)
              (setq root-two-edit (my/tab-current-property 'my/layout-edit-buffer))
              (should (equal (my/tab-current-property 'my/workspace-root) root-two))
              (should (derived-mode-p 'dired-mode))
              (my/tab-set-current-property 'my/work-task-id "old-task")
              (my/tab-set-current-property 'my/layout-companion-buffers
                                           '((terminal . old-companion)))
              (my/tab-set-current-property 'my/layout-terminal-target '(:name "terminal"))
              (my/tab-set-current-property 'my/layout-agent-target '(:name "agent"))
              (my/tab-set-current-property 'my/layout-agent-backend 'terminal-agent)
              (my/tab-set-current-property 'my/layout-agent-task-id "old-task")
              (my/tab-set-current-property 'my/layout-gptel-task-id "old-task")
              (my/tab-set-current-property 'my/send-text-last-target '(:name "last-target"))
              (my/workspace-select root-one)
              (let ((dired-called nil))
                (cl-letf (((symbol-function 'dired-noselect)
                           (lambda (&rest _arguments)
                             (setq dired-called t)
                             (error "Existing tab must not prepare Dired"))))
                  (my/workspace-select root-two))
                (should-not dired-called))
              (should (equal (my/tab-current-property 'my/workspace-root) root-two))
              (should (eq (my/tab-current-property 'my/layout-edit-buffer) root-two-edit))
              (should (equal (my/tab-current-property 'my/work-task-id) "old-task"))
              (let ((tabs-before (copy-tree tabs))
                    (buffers-before (my/layout-test-window-buffers))
                    (dired-called nil))
                (cl-letf (((symbol-function 'dired-noselect)
                           (lambda (&rest _arguments)
                             (setq dired-called t)
                             (error "Duplicate rebind must fail first"))))
                  (should-error (my/workspace-select root-one t) :type 'user-error))
                (should-not dired-called)
                (should (equal tabs tabs-before))
                (should (equal (my/layout-test-window-buffers) buffers-before)))
              (my/workspace-select root-four t)
              (should (equal (my/tab-current-property 'my/workspace-root) root-four))
              (should (eq (my/tab-current-property 'my/layout-edit-buffer)
                          (window-buffer (selected-window))))
              (should (derived-mode-p 'dired-mode))
              (should-not (my/tab-current-property 'my/work-task-id))
              (should-not (my/tab-current-property 'my/layout-companion-buffers))
              (should-not (my/tab-current-property 'my/layout-terminal-target))
              (should-not (my/tab-current-property 'my/layout-agent-target))
              (should-not (my/tab-current-property 'my/layout-agent-backend))
              (should-not (my/tab-current-property 'my/layout-agent-task-id))
              (should-not (my/tab-current-property 'my/layout-gptel-task-id))
              (should-not (my/tab-current-property 'my/send-text-last-target))
              (let ((tabs-before (copy-tree tabs))
                    (buffers-before (my/layout-test-window-buffers))
                    (root-before (my/tab-current-property 'my/workspace-root))
                    (edit-before (my/tab-current-property 'my/layout-edit-buffer)))
                (cl-letf (((symbol-function 'dired-noselect)
                           (lambda (_directory) (user-error "Dired preparation failed"))))
                  (should-error (my/workspace-select root-three t) :type 'user-error))
                (should (equal tabs tabs-before))
                (should (equal (my/layout-test-window-buffers) buffers-before))
                (should (equal (my/tab-current-property 'my/workspace-root) root-before))
                (should (eq (my/tab-current-property 'my/layout-edit-buffer) edit-before))))
          (mapc (lambda (buffer)
                  (when (buffer-live-p buffer)
                    (kill-buffer buffer)))
                (delete-dups (list source root-two-edit)))
          (delete-directory temporary-root t))))))

(provide 'window-layouts-test)

;;; window-layouts-test.el ends here
