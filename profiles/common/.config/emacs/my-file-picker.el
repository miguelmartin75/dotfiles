;;; my-file-picker.el --- Toggle hierarchical and recursive file pickers -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'dired)
(require 'files)
(require 'project)
(require 'subr-x)
(require 'tramp)
(require 'transient)

(declare-function consult-fd "consult" (&optional dir initial))
(declare-function consult-find "consult" (&optional dir initial))
(declare-function evil-set-jump "evil-jumps" (&optional pos))
(declare-function ivy-exit-with-action "ivy" (action &optional exit-code))
(declare-function ivy-read "ivy" (prompt collection &rest arguments))
(declare-function ivy-update-candidates "ivy" (candidates))
(declare-function my/call-with-native-completion
                  "my-completion-stack" (function &rest arguments))

(defvar consult-async-split-style)
(defvar consult-async-split-styles-alist)
(defvar consult-fd-args)
(defvar consult-find-args)
(defvar my/completion-stack)

(defconst my/file-picker-fd-base-args
  '("fd" "--full-path" "--color=never" "--type" "f" "--exclude" ".git")
  "Base fd arguments shared by Consult and the local fzf adapter.")

(defconst my/file-picker-remote-find-args
  '("find" "." "-type" "d" "-name" ".git" "-prune" "-name" ""
    "-o" "-type" "f")
  "Portable remote find arguments used when fd is unavailable.")

(defconst my/file-picker-fzf-default-args
  '("--root=project" "--hidden" "--no-ignore" "--case=insensitive")
  "Default saved arguments for recursive file discovery.")

(cl-defstruct my/file-picker-ivy-fzf-session
  root
  generation
  fd-process
  fzf-process
  fd-buffer
  fzf-buffer
  tail
  candidates
  minibuffer
  active
  export-buffer)

(defvar my/file-picker-result nil
  "Dynamically bound result recorded when a file prompt exits early.")

(defvar my/file-picker-active-ivy-fzf-session nil
  "Active repository-owned Ivy fzf session, or nil.")

(defvar-local my/file-picker-kind nil
  "Discovery kind of the current file picker minibuffer.")

(defvar-local my/file-picker-root nil
  "Unabbreviated root of the current file picker minibuffer.")

(defvar-local my/file-picker-query-syntax nil
  "Query syntax of the current recursive picker minibuffer.")

(defvar my/file-picker-minibuffer-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-c C-r" #'my/file-picker-toggle)
    map)
  "Keymap added locally to native file picker minibuffers.")

(defvar my/file-picker-ivy-fzf-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-c C-r" #'my/file-picker-toggle)
    (keymap-set map "C-q" #'my/file-picker-fzf-export)
    map)
  "Keymap composed with Ivy for the repository-owned fzf reader.")

(defun my/file-picker-record-jump-after-visit (source-marker visited-buffer)
  "Record SOURCE-MARKER after VISITED-BUFFER successfully changes buffers."
  (when (and (buffer-live-p visited-buffer)
             (not (eq (marker-buffer source-marker) visited-buffer)))
    (evil-set-jump source-marker)))

(defun my/file-picker-setup (kind root query-syntax)
  "Configure the current minibuffer for KIND below ROOT using QUERY-SYNTAX."
  (setq-local my/file-picker-kind kind
              my/file-picker-root root
              my/file-picker-query-syntax query-syntax)
  (use-local-map
   (make-composed-keymap my/file-picker-minibuffer-map (current-local-map))))

(defun my/file-picker-toggle ()
  "Exit the active file prompt and request its other discovery mode."
  (interactive)
  (unless (and (minibufferp) my/file-picker-kind my/file-picker-root)
    (user-error "No file picker is active"))
  (let ((input (minibuffer-contents-no-properties)))
    (when (and (memq my/file-picker-kind '(hierarchical project))
               (string-match "\\`/\\([^/:]+\\):" input)
               (assoc-string (match-string 1 input) tramp-methods)
               (or (not (file-remote-p input))
                   (string-empty-p
                    (or (tramp-file-name-host
                         (tramp-dissect-file-name input t))
                        ""))))
      (user-error "Complete the remote host before recursive search"))
    (setq my/file-picker-result
          (list (if (memq my/file-picker-kind '(hierarchical project))
                    'toggle-recursive
                  'toggle-hierarchical)
                input))
    (abort-recursive-edit)))

(defun my/file-picker-prompt-result (kind root query-syntax function)
  "Run one KIND prompt below ROOT with QUERY-SYNTAX by calling FUNCTION."
  (let ((my/file-picker-result nil)
        result)
    (condition-case nil
        (setq result
              (list 'selected
                    (minibuffer-with-setup-hook
                        (lambda ()
                          (my/file-picker-setup kind root query-syntax))
                      (funcall function))))
      (quit
       (setq result (or my/file-picker-result '(cancel)))))
    result))

(defun my/file-picker-literal-query (query)
  "Return QUERY as literal filename text, or nil when it has Consult syntax."
  (let* ((active-style (and (boundp 'consult-async-split-style)
                            consult-async-split-style))
         (style (and (boundp 'consult-async-split-styles-alist)
                     (alist-get active-style
                                consult-async-split-styles-alist)))
         (initial (plist-get style :initial))
         (removed-initial (and initial
                               (< 0 (length query))
                               (= initial (aref query 0))))
         (query (if removed-initial (substring query 1) query))
         (index 0)
         (literal "")
         invalid)
    (when (or (string-match-p " +--\\( +\\|\\'\\)" query)
              (and removed-initial
                   (string-match-p
                    (regexp-quote (char-to-string initial)) query))
              (and (eq active-style 'perl)
                   (not removed-initial)
                   (string-match-p "^[[:punct:]]" query))
              (and (memq active-style '(comma semicolon))
                   (let ((separator (plist-get style :separator)))
                     (and separator
                          (string-match-p
                           (format "^[^%s]+%s"
                                   (regexp-quote
                                    (char-to-string separator))
                                   (regexp-quote
                                    (char-to-string separator)))
                           query)))))
      (setq invalid t))
    (while (and (not invalid) (< index (length query)))
      (let ((character (aref query index)))
        (if (= character ?\\)
            (if (= (1+ index) (length query))
                (setq invalid t)
              (setq literal
                    (concat literal (char-to-string (aref query (1+ index))))
                    index (1+ index)))
          (when (memq character '(?\[ ?\] ?^ ?$ ?| ?? ?* ?+ ?\( ?\)))
            (setq invalid t))
          (setq literal (concat literal (char-to-string character)))))
      (setq index (1+ index)))
    (unless invalid
      (if (string-match-p "\\\\" query)
          (when (string-equal query (regexp-quote literal)) literal)
        query))))

(defun my/file-picker-hierarchical-session (root initial)
  "Read one file hierarchically below ROOT with literal INITIAL text."
  (let ((read-root (if (and initial (file-name-absolute-p initial))
                       (file-name-directory initial)
                     root))
        (read-initial (if (and initial (file-name-absolute-p initial))
                          (file-name-nondirectory initial)
                        initial)))
    (my/file-picker-prompt-result
     'hierarchical root 'literal
     (lambda ()
       (read-file-name "Find file: " read-root nil nil read-initial)))))

(defun my/file-picker-project-session (project root initial)
  "Read one PROJECT file below ROOT with relative display and INITIAL text."
  (let (candidates)
    (dolist (file (project-files project))
      (let ((absolute (if (file-name-absolute-p file)
                          file
                        (expand-file-name file root))))
        (push (cons (file-relative-name absolute root) absolute) candidates)))
    (setq candidates (nreverse candidates))
    (unless candidates
      (user-error "Project has no files"))
    (my/file-picker-prompt-result
     'project root 'literal
     (lambda ()
       (let* ((display
               (completing-read
                (format "Find file in %s: " root)
                candidates nil t initial 'file-name-history))
              (selected
               (or (assoc-string display candidates)
                   (assoc-string display candidates completion-ignore-case))))
         (cdr selected))))))

(defun my/file-picker-fd-arguments (args)
  "Translate stack-neutral Transient ARGS into one fd argv list."
  (let ((result (copy-sequence my/file-picker-fd-base-args)))
    (dolist (argument '("--hidden" "--no-ignore" "--follow"))
      (when (member argument args)
        (setq result (append result (list argument)))))
    (pcase (transient-arg-value "--case=" args)
      ("sensitive"
       (setq result (append result '("--case-sensitive"))))
      ("smart")
      (_
       (setq result (append result '("--ignore-case")))))
    result))

(defun my/file-picker-fzf-arguments (query args)
  "Translate QUERY and stack-neutral ARGS into one fzf argv list."
  (let ((result
         (list "fzf" "--read0" "--print0" "--no-multi-line"
               (pcase (transient-arg-value "--case=" args)
                 ("sensitive" "+i")
                 ("smart" "--smart-case")
                 (_ "--ignore-case"))
               (concat "--filter=" (or query "")))))
    result))

(defun my/file-picker-consult-recursive-session (root initial args remote)
  "Run one Consult recursive prompt below ROOT using INITIAL and saved ARGS.

When REMOTE is non-nil, prefer remote fd and use portable find otherwise."
  (let ((default-directory root)
        (consult-async-split-style nil)
        (consult-fd-args (my/file-picker-fd-arguments args)))
    (if (and remote (not (executable-find "fd" t)))
        (progn
          (unless (string-equal
                   (or (transient-arg-value "--case=" args) "insensitive")
                   "insensitive")
            (user-error
             "Portable remote find supports only case-insensitive matching"))
          (let ((consult-find-args
                 (if (member "--follow" args)
                     (append '("find" "-L")
                             (cdr my/file-picker-remote-find-args))
                   my/file-picker-remote-find-args)))
            (my/file-picker-prompt-result
             'recursive root 'consult
             (lambda ()
               (let ((selected (consult-find root initial)))
                 (if (bufferp selected)
                     (buffer-file-name selected)
                   selected))))))
      (my/file-picker-prompt-result
       'recursive root 'consult
       (lambda ()
         (let ((selected (consult-fd root initial)))
           (if (bufferp selected)
               (buffer-file-name selected)
             selected)))))))

(defun my/file-picker-current-fzf-generation-p (session generation)
  "Return non-nil when SESSION still owns GENERATION."
  (and (my/file-picker-ivy-fzf-session-active session)
       (eq session my/file-picker-active-ivy-fzf-session)
       (= generation (my/file-picker-ivy-fzf-session-generation session))))

(defun my/file-picker-stop-fzf-processes (session)
  "Stop and clear both processes and temporary buffers owned by SESSION."
  (dolist (process (list (my/file-picker-ivy-fzf-session-fd-process session)
                         (my/file-picker-ivy-fzf-session-fzf-process session)))
    (when (process-live-p process)
      (delete-process process)))
  (dolist (buffer (list (my/file-picker-ivy-fzf-session-fd-buffer session)
                        (my/file-picker-ivy-fzf-session-fzf-buffer session)))
    (when (buffer-live-p buffer)
      (kill-buffer buffer)))
  (setf (my/file-picker-ivy-fzf-session-fd-process session) nil
        (my/file-picker-ivy-fzf-session-fzf-process session) nil
        (my/file-picker-ivy-fzf-session-fd-buffer session) nil
        (my/file-picker-ivy-fzf-session-fzf-buffer session) nil))

(defun my/file-picker-close-fzf-session (session)
  "Invalidate and release every resource owned by SESSION."
  (setf (my/file-picker-ivy-fzf-session-active session) nil
        (my/file-picker-ivy-fzf-session-generation session)
        (1+ (my/file-picker-ivy-fzf-session-generation session)))
  (my/file-picker-stop-fzf-processes session)
  (when (eq session my/file-picker-active-ivy-fzf-session)
    (setq my/file-picker-active-ivy-fzf-session nil)))

(defun my/file-picker-fd-filter (session generation process output)
  "Forward fd OUTPUT to SESSION fzf for GENERATION and PROCESS."
  (when (and (my/file-picker-current-fzf-generation-p session generation)
             (eq process
                 (my/file-picker-ivy-fzf-session-fd-process session))
             (process-live-p
              (my/file-picker-ivy-fzf-session-fzf-process session)))
    (condition-case nil
        (process-send-string
         (my/file-picker-ivy-fzf-session-fzf-process session) output)
      (error nil))))

(defun my/file-picker-fd-sentinel (session generation process)
  "Close fzf input when fd PROCESS finishes for SESSION GENERATION."
  (when (and (my/file-picker-current-fzf-generation-p session generation)
             (eq process
                 (my/file-picker-ivy-fzf-session-fd-process session))
             (memq (process-status process) '(exit signal)))
    (let ((fzf-process
           (my/file-picker-ivy-fzf-session-fzf-process session)))
      (if (and (= (process-exit-status process) 0)
               (process-live-p fzf-process))
          (condition-case nil
              (process-send-eof fzf-process)
            (error nil))
        (when (process-live-p fzf-process)
          (delete-process fzf-process))
        (message "fd file discovery failed with status %s"
                 (process-exit-status process))))))

(defun my/file-picker-fzf-filter (session generation process output)
  "Parse NUL-delimited fzf OUTPUT for SESSION GENERATION and PROCESS."
  (when (and (my/file-picker-current-fzf-generation-p session generation)
             (eq process
                 (my/file-picker-ivy-fzf-session-fzf-process session)))
    (let ((data (concat (my/file-picker-ivy-fzf-session-tail session) output))
          (start 0)
          records)
      (while (string-match "\0" data start)
        (let ((record (substring data start (match-beginning 0))))
          (unless (string-empty-p record)
            (push record records)))
        (setq start (match-end 0)))
      (setf (my/file-picker-ivy-fzf-session-tail session)
            (substring data start)
            (my/file-picker-ivy-fzf-session-candidates session)
            (nconc (my/file-picker-ivy-fzf-session-candidates session)
                   (nreverse records)))
      (let ((minibuffer
             (my/file-picker-ivy-fzf-session-minibuffer session))
            (window (active-minibuffer-window)))
        (when (and (buffer-live-p minibuffer)
                   (window-live-p window)
                   (eq minibuffer (window-buffer window)))
          (with-current-buffer minibuffer
            (ivy-update-candidates
             (copy-sequence
              (my/file-picker-ivy-fzf-session-candidates session)))))))))

(defun my/file-picker-fzf-sentinel (session generation process)
  "Report an active fzf PROCESS failure for SESSION GENERATION."
  (let ((state (process-status process)))
    (when (and (my/file-picker-current-fzf-generation-p session generation)
               (eq process
                   (my/file-picker-ivy-fzf-session-fzf-process session))
               (memq state '(exit signal)))
      (let ((status (process-exit-status process)))
        (unless (or (= status 0)
                    (and (eq state 'exit) (= status 1)))
          (message "fzf file discovery failed with status %s" status))))))

(defun my/file-picker-start-fzf-generation (session args query)
  "Replace SESSION processes with one generation for ARGS and QUERY."
  (setf (my/file-picker-ivy-fzf-session-generation session)
        (1+ (my/file-picker-ivy-fzf-session-generation session)))
  (my/file-picker-stop-fzf-processes session)
  (let* ((generation (my/file-picker-ivy-fzf-session-generation session))
         (fd-buffer (generate-new-buffer " *file-picker-fd*"))
         (fzf-buffer (generate-new-buffer " *file-picker-fzf*"))
         (default-directory (my/file-picker-ivy-fzf-session-root session)))
    (setf (my/file-picker-ivy-fzf-session-tail session) ""
          (my/file-picker-ivy-fzf-session-candidates session) nil
          (my/file-picker-ivy-fzf-session-minibuffer session)
          (and (minibufferp) (current-buffer))
          (my/file-picker-ivy-fzf-session-fd-buffer session) fd-buffer
          (my/file-picker-ivy-fzf-session-fzf-buffer session) fzf-buffer)
    (condition-case condition
        (progn
          (setf
           (my/file-picker-ivy-fzf-session-fzf-process session)
           (make-process
            :name (format "file-picker-fzf-%d" generation)
            :buffer fzf-buffer
            :stderr fzf-buffer
            :command (my/file-picker-fzf-arguments query args)
            :coding (or file-name-coding-system
                        default-file-name-coding-system
                        'utf-8-unix)
            :connection-type 'pipe
            :noquery t
            :filter
            (lambda (process output)
              (my/file-picker-fzf-filter
               session generation process output))
            :sentinel
            (lambda (process _event)
              (my/file-picker-fzf-sentinel session generation process))))
          (setf
           (my/file-picker-ivy-fzf-session-fd-process session)
           (make-process
            :name (format "file-picker-fd-%d" generation)
            :buffer fd-buffer
            :stderr fd-buffer
            :command (append (my/file-picker-fd-arguments args)
                             '("--print0"))
            :coding (or file-name-coding-system
                        default-file-name-coding-system
                        'utf-8-unix)
            :connection-type 'pipe
            :noquery t
            :filter
            (lambda (process output)
              (my/file-picker-fd-filter session generation process output))
            :sentinel
            (lambda (process _event)
              (my/file-picker-fd-sentinel session generation process))))
          0)
      ((error quit)
       (my/file-picker-stop-fzf-processes session)
       (signal (car condition) (cdr condition))))))

(defun my/file-picker-fzf-collection (session args query &rest ignored)
  "Start a new SESSION generation for saved ARGS and editable QUERY."
  (ignore ignored)
  (my/file-picker-start-fzf-generation session args query))

(defun my/file-picker-fzf-export ()
  "Exit Ivy and open a Dired snapshot of the active safe fzf candidates."
  (interactive)
  (let ((session my/file-picker-active-ivy-fzf-session))
    (unless (and session
                 (my/file-picker-ivy-fzf-session-active session))
      (user-error "No safe fzf file session is active"))
    (let* ((root (my/file-picker-ivy-fzf-session-root session))
           (files
            (mapcar (lambda (candidate)
                      (expand-file-name candidate root))
                    (copy-sequence
                     (my/file-picker-ivy-fzf-session-candidates session)))))
      (unless files
        (user-error "The fzf file session has no candidates to persist"))
      (ivy-exit-with-action
       (lambda (_candidate)
         (let ((result (dired (cons root files))))
           (setf (my/file-picker-ivy-fzf-session-export-buffer session) result)
           result))))))

(defun my/file-picker-ivy-fzf-session (root initial args)
  "Run one safe local Ivy fzf prompt below ROOT with INITIAL and saved ARGS."
  (unless (executable-find "fd")
    (user-error "Required program \"fd\" not found in your path"))
  (unless (executable-find "fzf")
    (user-error "Required program \"fzf\" not found in your path"))
  (require 'ivy)
  (let* ((session
          (make-my/file-picker-ivy-fzf-session
           :root root :generation 0 :tail "" :active t))
         (my/file-picker-active-ivy-fzf-session session)
         (my/file-picker-result nil)
         selected
         result)
    (unwind-protect
        (progn
          (condition-case nil
              (setq selected
                    (minibuffer-with-setup-hook
                        (lambda ()
                          (setq-local my/file-picker-kind 'recursive
                                      my/file-picker-root root
                                      my/file-picker-query-syntax 'literal)
                          (setf
                           (my/file-picker-ivy-fzf-session-minibuffer session)
                           (current-buffer)))
                      (ivy-read
                       "Fzf files: "
                       (lambda (query &rest ignored)
                         (apply #'my/file-picker-fzf-collection
                                session args query ignored))
                       :dynamic-collection t
                       :require-match t
                       :initial-input initial
                       :keymap my/file-picker-ivy-fzf-map
                       :sort nil
                       :caller 'my/file-picker-ivy-fzf)))
            (quit
             (setq result (or my/file-picker-result '(cancel)))))
          (unless result
            (setq result
                  (if (buffer-live-p
                       (my/file-picker-ivy-fzf-session-export-buffer session))
                      '(cancel)
                    (if (stringp selected)
                        (list 'selected (expand-file-name selected root))
                      '(cancel)))))
          result)
      (my/file-picker-close-fzf-session session))))

(defun my/file-picker-recursive-session (root initial &optional literal-initial)
  "Run one recursive prompt below ROOT with INITIAL.

When LITERAL-INITIAL is non-nil, translate INITIAL for Consult but pass it
unchanged to the safe Ivy fzf reader."
  (let* ((args (transient-args 'my/file-picker-fzf-menu))
         (remote (file-remote-p root))
         (consult-initial (if (and literal-initial initial)
                              (regexp-quote initial)
                            initial))
         result)
    (cond
     (remote
      (setq result
            (if (eq my/completion-stack 'ivy-counsel)
                (my/call-with-native-completion
                 #'my/file-picker-consult-recursive-session
                 root consult-initial args t)
              (my/file-picker-consult-recursive-session
               root consult-initial args t))))
     ((eq my/completion-stack 'ivy-counsel)
      (setq result (my/file-picker-ivy-fzf-session root initial args)))
     (t
      (setq result
            (my/file-picker-consult-recursive-session
             root consult-initial args nil))))
    result))

(defun my/file-picker-run (kind root initial &optional project)
  "Run one frontend-neutral file transaction of KIND below ROOT.

INITIAL seeds the first prompt.  PROJECT supplies the public project object
when KIND is `project'."
  (let ((source-marker (point-marker))
        (current-kind kind)
        (current-root root)
        (current-initial initial)
        (literal-initial (memq kind '(hierarchical project)))
        result)
    (unwind-protect
        (progn
          (while current-kind
            (let ((prompt-result
                   (pcase current-kind
                     ('hierarchical
                      (my/file-picker-hierarchical-session
                       current-root current-initial))
                     ('project
                      (my/file-picker-project-session
                       project current-root current-initial))
                     ('recursive
                      (my/file-picker-recursive-session
                       current-root current-initial literal-initial)))))
              (pcase prompt-result
                (`(selected ,path)
                 (setq result (find-file path)
                       current-kind nil))
                (`(toggle-recursive ,query)
                 (let* ((directory (file-name-directory query))
                        (next-root
                         (if directory
                             (if (file-name-absolute-p directory)
                                 directory
                               (expand-file-name directory current-root))
                           current-root)))
                   (setq current-kind 'recursive
                         current-root next-root
                         current-initial (file-name-nondirectory query)
                         literal-initial t)))
                (`(toggle-hierarchical ,query)
                 (setq current-initial
                       (if (or (file-remote-p current-root)
                               (eq my/completion-stack 'native-consult))
                           (my/file-picker-literal-query query)
                         query)
                       current-kind 'hierarchical
                       literal-initial t))
                (`(cancel)
                 (setq current-kind nil)))))
          (my/file-picker-record-jump-after-visit source-marker result)
          result)
      (set-marker source-marker nil))))

(defun my/find-file (&optional root initial)
  "Open a file hierarchically below ROOT with optional INITIAL leaf text."
  (interactive)
  (my/file-picker-run 'hierarchical (or root default-directory) initial))

(defun my/find-file-recursive (root &optional initial)
  "Recursively select and open a file below ROOT with optional INITIAL query."
  (my/file-picker-run 'recursive root initial))

(defun my/find-file-recursive-configured ()
  "Run recursive discovery below the saved project or directory root."
  (interactive)
  (let* ((args (transient-args 'my/file-picker-fzf-menu))
         (root
          (if (string-equal (transient-arg-value "--root=" args) "directory")
              default-directory
            (let ((project (project-current)))
              (if project (project-root project) default-directory)))))
    (my/find-file-recursive root)))

(defun my/find-file-recursive-root ()
  "Recursively search all files below the project or default directory."
  (interactive)
  (let ((project (project-current)))
    (my/find-file-recursive
     (if project (project-root project) default-directory))))

(transient-define-prefix my/file-picker-fzf-menu ()
  "Configure recursive file discovery for either completion stack."
  :value my/file-picker-fzf-default-args
  :remember-value '(export save)
  [["Scope"
    ("r" "Root" "--root="
     :choices '("project" "directory")
     :always-read t)]
   ["Files"
    ("h" "Include hidden files" "--hidden")
    ("i" "Include ignored files" "--no-ignore")
    ("f" "Follow symlinks" "--follow")]
   ["Matching"
    ("c" "Case" "--case="
     :choices '("insensitive" "smart" "sensitive")
     :always-read t)]
   ["Actions"
    ("RET" "Find file" my/find-file-recursive-configured)]])

(defun my/find-file-project ()
  "Select and open a project file through the active minibuffer frontend."
  (interactive)
  (let* ((project (project-current t))
         (root (project-root project)))
    (my/file-picker-run 'project root nil project)))

(defun my/find-file-recursive-current-directory ()
  "Recursively search all files below the current file's directory."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (my/find-file-recursive (file-name-directory buffer-file-name)))

(defun my/find-file-sshx ()
  "Open a remote file hierarchically with an SSH host prompt."
  (interactive)
  (my/find-file default-directory "/sshx:"))

(provide 'my-file-picker)

;;; my-file-picker.el ends here
