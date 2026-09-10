;;; my-search.el --- Stack-aware search commands -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'compile)
(require 'grep)
(require 'json)
(require 'project)
(require 'subr-x)
(require 'transient)

(declare-function consult-buffer "consult")
(declare-function consult-line "consult" (&optional initial start))
(declare-function consult-line-multi "consult" (query &optional initial))
(declare-function consult-project-buffer "consult")
(declare-function consult-ripgrep "consult" (&optional dir initial))
(declare-function ivy-exit-with-action "ivy" (action &optional exit-code))
(declare-function ivy-read "ivy" (prompt collection &rest arguments))
(declare-function ivy-switch-buffer "ivy" (&optional arg))
(declare-function ivy-update-candidates "ivy" (candidates))
(declare-function my/call-with-native-completion
                  "my-completion-stack" (function &rest arguments))
(declare-function swiper-all "swiper" (&optional initial-input))
(declare-function swiper-isearch "swiper" (&optional initial-input))

(defvar consult-buffer-list-function)
(defvar consult-line-start-from-top)
(defvar consult-ripgrep-args)
(defvar consult-async-split-style)
(defvar ivy-case-fold-search-default)
(defvar ivy-exit nil)
(defvar my/completion-stack)

(defconst my/search-line-default-args
  '("--case=insensitive" "--origin=point")
  "Default saved arguments for current-buffer line search.")

(defconst my/search-lines-default-args
  '("--case=insensitive" "--scope=all")
  "Default saved arguments for multi-buffer line search.")

(defconst my/search-buffer-default-args
  '("--case=insensitive" "--scope=all")
  "Default saved arguments for buffer selection.")

(defconst my/search-ripgrep-default-args
  '("--root=project" "--hidden" "--no-ignore" "--case=insensitive"
    "--matching=regexp" "--context=0")
  "Default saved arguments for ripgrep search.")

(defconst my/search-rg-base-arguments
  '("rg" "--json" "--line-buffered" "--color=never" "--no-heading"
    "--with-filename" "--line-number" "--max-columns=1000")
  "Arguments common to every repository-owned ripgrep process.")

(defvar my/consult-live-buffer-source
  `(:name "Buffer"
    :narrow ?b
    :category buffer
    :history buffer-name-history
    :default t
    :items
    ,(lambda ()
       (mapcar (lambda (buffer)
                 (cons (buffer-name buffer) buffer))
               (buffer-list)))
    :action ,#'switch-to-buffer)
  "Consult source containing only currently live buffers.")

(cl-defstruct my/search-rg-candidate
  file
  line
  column
  text
  matched)

(cl-defstruct my/search-rg-session
  root
  args
  generation
  process
  buffer
  tail
  candidates
  minibuffer
  origin-buffer
  origin-marker
  origin-window
  origin-window-start
  preview-candidate
  active
  stopping
  visited
  export-buffer)

(defvar my/search-active-rg-session nil
  "Active repository-owned Ivy ripgrep session, or nil.")

(defvar my/search-rg-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-q" #'my/search-rg-export)
    map)
  "Keymap added to the repository-owned Ivy ripgrep reader.")

(defun my/search-argument (name args &optional default)
  "Return saved transient value for NAME in ARGS, or DEFAULT."
  (or (transient-arg-value name args) default))

(defun my/search-case-fold-p (args)
  "Return whether ARGS requests case-insensitive Emacs-side matching."
  (not (string-equal (my/search-argument "--case=" args "insensitive")
                     "sensitive")))

(defun my/search-ivy-case-fold-p (args)
  "Return Ivy's case-fold setting translated from ARGS."
  (pcase (my/search-argument "--case=" args "insensitive")
    ("sensitive" nil)
    ("smart" 'auto)
    (_ t)))

(defun my/search-root (args)
  "Return the project or current-directory root selected by ARGS."
  (let ((project (project-current)))
    (file-name-as-directory
     (if (and (string-equal (my/search-argument "--root=" args "project")
                            "project")
              project)
         (project-root project)
       default-directory))))

(defun my/search-project-buffers ()
  "Return the live buffers belonging to the current public project."
  (project-buffers (project-current t)))

(defun my/search-project-buffer-candidates ()
  "Return public project buffers and files as a completion alist."
  (let* ((project (project-current t))
         (root (file-name-as-directory (project-root project)))
         (buffers (my/search-project-buffers))
         result)
    (dolist (buffer buffers)
      (push (cons (format "%s (buffer)" (buffer-name buffer)) buffer) result))
    (dolist (file (project-files project))
      (let ((absolute (if (file-name-absolute-p file)
                          file
                        (expand-file-name file root))))
        (unless (seq-some (lambda (buffer)
                            (let ((buffer-file (buffer-file-name buffer)))
                              (and buffer-file
                                   (string-equal buffer-file absolute))))
                          buffers)
          (push (cons (file-relative-name absolute root) absolute) result))))
    (nreverse result)))

(defun my/search-run-with-preview-restoration (function)
  "Run FUNCTION and restore the origin when its preview is cancelled."
  (let ((origin-buffer (current-buffer))
        (origin-marker (point-marker))
        (origin-window (selected-window))
        (origin-window-start (window-start))
        accepted
        result)
    (unwind-protect
        (progn
          (setq result (funcall function)
                accepted t)
          result)
      (unless accepted
        (when (and (buffer-live-p origin-buffer)
                   (marker-buffer origin-marker)
                   (window-live-p origin-window))
          (with-selected-window origin-window
            (switch-to-buffer origin-buffer)
            (goto-char origin-marker)
            (set-window-start origin-window origin-window-start t))))
      (set-marker origin-marker nil))))

(defun my/search-line ()
  "Search current-buffer lines with the applied completion stack."
  (interactive)
  (let ((args (transient-args 'my/search-line-menu)))
    (my/search-run-with-preview-restoration
     (lambda ()
       (let* ((case-fold-search (my/search-case-fold-p args))
              (completion-ignore-case (my/search-case-fold-p args))
              (ivy-case-fold-search-default (my/search-ivy-case-fold-p args))
              (consult-line-start-from-top
               (string-equal (my/search-argument "--origin=" args "point")
                             "top"))
              (start (and consult-line-start-from-top (point-min))))
         (if (eq my/completion-stack 'ivy-counsel)
             (progn
               (when start
                 (goto-char start))
               (swiper-isearch))
           (consult-line nil start)))))))

(defun my/search-consult-lines (buffers args)
  "Search BUFFERS through Consult using stack-neutral ARGS."
  (let ((case-fold-search (my/search-case-fold-p args))
        (completion-ignore-case (my/search-case-fold-p args))
        (consult-buffer-list-function (lambda () buffers)))
    (consult-line-multi '(:sort alpha-current :filter nil))))

(defun my/search-lines ()
  "Search multiple buffers with the applied completion stack."
  (interactive)
  (let ((args (transient-args 'my/search-lines-menu)))
    (my/search-run-with-preview-restoration
     (lambda ()
       (if (string-equal (my/search-argument "--scope=" args "all")
                         "project")
           (let ((buffers (my/search-project-buffers)))
             (if (eq my/completion-stack 'ivy-counsel)
                 (my/call-with-native-completion
                  #'my/search-consult-lines buffers args)
               (my/search-consult-lines buffers args)))
         (let ((case-fold-search (my/search-case-fold-p args))
               (completion-ignore-case (my/search-case-fold-p args))
               (ivy-case-fold-search-default (my/search-ivy-case-fold-p args)))
           (if (eq my/completion-stack 'ivy-counsel)
               (swiper-all)
             (consult-line-multi t))))))))

(defun my/select-project-buffer ()
  "Select a live project buffer or project file through completion."
  (let* ((candidates (my/search-project-buffer-candidates))
         (display (completing-read "Project buffer: " candidates nil t))
         (selected (cdr (assoc-string display candidates completion-ignore-case))))
    (if (bufferp selected)
        (switch-to-buffer selected)
      (find-file selected))))

(defun my/select-buffer ()
  "Select a buffer with the applied completion stack and saved scope."
  (interactive)
  (let ((args (transient-args 'my/search-buffer-menu)))
    (if (string-equal (my/search-argument "--scope=" args "all") "project")
        (let ((completion-ignore-case (my/search-case-fold-p args))
              (ivy-case-fold-search-default (my/search-ivy-case-fold-p args)))
          (if (eq my/completion-stack 'ivy-counsel)
              (my/select-project-buffer)
            (consult-project-buffer)))
      (let ((completion-ignore-case (my/search-case-fold-p args))
            (ivy-case-fold-search-default (my/search-ivy-case-fold-p args)))
        (if (eq my/completion-stack 'ivy-counsel)
            (ivy-switch-buffer)
          (consult-buffer))))))

(defun my/search-ripgrep-arguments (args query)
  "Translate recognized ARGS and QUERY into one argv-only rg command."
  (let ((result (copy-sequence my/search-rg-base-arguments))
        (case (my/search-argument "--case=" args "insensitive"))
        (matching (my/search-argument "--matching=" args "regexp"))
        (glob (my/search-argument "--glob=" args))
        (type (my/search-argument "--type=" args))
        (context (my/search-argument "--context=" args "0")))
    (dolist (argument '(("--hidden" . "--hidden")
                        ("--no-ignore" . "--no-ignore")
                        ("--follow" . "--follow")))
      (when (member (car argument) args)
        (setq result (append result (list (cdr argument))))))
    (setq result
          (append result
                  (pcase case
                    ("sensitive" '("--case-sensitive"))
                    ("smart" '("--smart-case"))
                    (_ '("--ignore-case")))
                  (if (string-equal matching "fixed")
                      '("--fixed-strings")
                    nil)
                  (if (string-empty-p (or glob "")) nil (list "--glob" glob))
                  (if (string-empty-p (or type "")) nil (list "--type" type))
                  (list "--context" context)
                  (if (string-match-p "\n" query) '("--multiline") nil)
                  (list "-e" query)))
    result))

(defun my/search-consult-ripgrep-arguments (args &optional query)
  "Translate ARGS and optional QUERY into `consult-ripgrep-args'."
  (let ((result
         '("rg" "--null" "--line-buffered" "--color=never"
           "--max-columns=1000" "--path-separator" "/" "--no-heading"
           "--with-filename" "--line-number" "--search-zip"))
        (case (my/search-argument "--case=" args "insensitive"))
        (matching (my/search-argument "--matching=" args "regexp"))
        (glob (my/search-argument "--glob=" args))
        (type (my/search-argument "--type=" args))
        (context (my/search-argument "--context=" args "0")))
    (dolist (argument '(("--hidden" . "--hidden")
                        ("--no-ignore" . "--no-ignore")
                        ("--follow" . "--follow")))
      (when (member (car argument) args)
        (setq result (append result (list (cdr argument))))))
    (setq result
          (append result
                  (pcase case
                    ("sensitive" '("--case-sensitive"))
                    ("smart" '("--smart-case"))
                    (_ '("--ignore-case")))
                  (if (string-equal matching "fixed")
                      '("--fixed-strings")
                    nil)
                  ;; Consult splits string elements, so dynamic values must
                  ;; evaluate to one-item lists at its public argument boundary.
                  (if (string-empty-p (or glob ""))
                      nil
                    (list "--glob" `(list ,glob)))
                  (if (string-empty-p (or type ""))
                      nil
                    (list "--type" `(list ,type)))
                  (list "--context" `(list ,context))
                  (if (and query (string-match-p "\n" query))
                      '("--multiline")
                    nil)))
    result))

(defun my/search-consult-ripgrep (root initial args)
  "Run Consult ripgrep below ROOT with INITIAL and translated ARGS."
  (let ((default-directory root)
        (consult-async-split-style nil)
        (consult-ripgrep-args
         (my/search-consult-ripgrep-arguments args initial)))
    (consult-ripgrep root initial)))

(defun my/search-rg-current-generation-p (session generation)
  "Return non-nil when SESSION still owns GENERATION."
  (and (my/search-rg-session-active session)
       (not (my/search-rg-session-stopping session))
       (eq session my/search-active-rg-session)
       (= generation (my/search-rg-session-generation session))))

(defun my/search-rg-stop-process (session)
  "Stop and release the process and temporary buffer owned by SESSION."
  (setf (my/search-rg-session-stopping session) t)
  (let ((process (my/search-rg-session-process session))
        (buffer (my/search-rg-session-buffer session)))
    (when (process-live-p process)
      (delete-process process))
    (when (buffer-live-p buffer)
      (kill-buffer buffer)))
  (setf (my/search-rg-session-process session) nil
        (my/search-rg-session-buffer session) nil))

(defun my/search-rg-close-session (session)
  "Invalidate SESSION and release its process resources."
  (setf (my/search-rg-session-active session) nil
        (my/search-rg-session-generation session)
        (1+ (my/search-rg-session-generation session)))
  (my/search-rg-stop-process session)
  (when (eq session my/search-active-rg-session)
    (setq my/search-active-rg-session nil)))

(defun my/search-rg-restore-origin (session)
  "Restore SESSION's point and window start after a cancelled preview."
  (let ((buffer (my/search-rg-session-origin-buffer session))
        (marker (my/search-rg-session-origin-marker session))
        (window (my/search-rg-session-origin-window session))
        (start (my/search-rg-session-origin-window-start session)))
    (when (and (buffer-live-p buffer)
               (marker-buffer marker)
               (window-live-p window))
      (with-selected-window window
        (switch-to-buffer buffer)
        (goto-char marker)
        (set-window-start window start t)))))

(defun my/search-rg-candidate-display (candidate root)
  "Return an Ivy display string for typed CANDIDATE below ROOT."
  (let* ((file (my/search-rg-candidate-file candidate))
         (display-file (if (file-name-absolute-p file)
                           (file-relative-name file root)
                         file))
         (text (replace-regexp-in-string
                "[\n\r]+" "\\\\n" (my/search-rg-candidate-text candidate))))
    (propertize
     (format "%s:%d:%d:%s" display-file
             (my/search-rg-candidate-line candidate)
             (my/search-rg-candidate-column candidate)
             text)
     'my/search-rg-candidate candidate)))

(defun my/search-rg-preview (session candidate)
  "Preview typed CANDIDATE in SESSION's source window."
  (when (and candidate (window-live-p (my/search-rg-session-origin-window session)))
    (with-selected-window (my/search-rg-session-origin-window session)
      (find-file (my/search-rg-candidate-file candidate))
      (goto-char (point-min))
      (forward-line (1- (my/search-rg-candidate-line candidate)))
      (move-to-column (1- (my/search-rg-candidate-column candidate))))
    (setf (my/search-rg-session-preview-candidate session) candidate)))

(defun my/search-rg-publish (session)
  "Publish SESSION's current typed candidates through public Ivy APIs."
  (let ((minibuffer (my/search-rg-session-minibuffer session))
        (window (active-minibuffer-window))
        (candidates
         (mapcar (lambda (candidate)
                   (my/search-rg-candidate-display
                    candidate (my/search-rg-session-root session)))
                 (my/search-rg-session-candidates session))))
    (when (and (not (buffer-live-p minibuffer))
               (window-live-p window))
      (setq minibuffer (window-buffer window))
      (setf (my/search-rg-session-minibuffer session) minibuffer))
    (when (and (buffer-live-p minibuffer)
               (window-live-p window)
               (eq minibuffer (window-buffer window)))
      (with-current-buffer minibuffer
        (ivy-update-candidates candidates)))))

(defun my/search-rg-json-candidate (record root)
  "Parse one ripgrep JSON RECORD below ROOT into typed candidate metadata."
  (condition-case nil
      (let* ((json (json-parse-string record :object-type 'hash-table
                                       :array-type 'list))
             (type (gethash "type" json))
             (data (gethash "data" json)))
        (when (member type '("match" "context"))
          (let* ((path (gethash "text" (gethash "path" data)))
                 (lines (gethash "text" (gethash "lines" data)))
                 (line (or (gethash "line_number" data) 1))
                 (submatches (gethash "submatches" data))
                 (first-match (car submatches))
                 (byte-column (or (and first-match
                                       (gethash "start" first-match))
                                  0))
                 (column
                  (1+ (length
                       (decode-coding-string
                        (substring (encode-coding-string lines 'utf-8)
                                   0 byte-column)
                        'utf-8)))) )
            (when (and (stringp path) (stringp lines))
              (make-my/search-rg-candidate
               :file (if (file-name-absolute-p path)
                         path
                       (expand-file-name path root))
               :line line
               :column column
               :text (replace-regexp-in-string "[\r\n]+\\'" "" lines)
               :matched (string-equal type "match"))))))
    (error nil)))

(defun my/search-rg-filter (session generation process output)
  "Parse current-generation ripgrep JSON OUTPUT for SESSION and PROCESS."
  (when (and (my/search-rg-current-generation-p session generation)
             (eq process (my/search-rg-session-process session)))
    (let ((data (concat (my/search-rg-session-tail session) output))
          (start 0)
          records)
      (while (string-match "\n" data start)
        (push (substring data start (match-beginning 0)) records)
        (setq start (match-end 0)))
      (setf (my/search-rg-session-tail session) (substring data start))
      (dolist (record (nreverse records))
        (when-let* ((candidate
                     (my/search-rg-json-candidate
                      record (my/search-rg-session-root session))))
          (setf (my/search-rg-session-candidates session)
                (nconc (my/search-rg-session-candidates session)
                       (list candidate)))))
      (my/search-rg-publish session))))

(defun my/search-rg-sentinel (session generation process)
  "Report an active ripgrep PROCESS failure for SESSION GENERATION."
  (let ((state (process-status process)))
    (when (and (my/search-rg-current-generation-p session generation)
               (eq process (my/search-rg-session-process session))
               (memq state '(exit signal)))
      (let ((status (process-exit-status process)))
        (unless (or (= status 0)
                    (and (eq state 'exit) (= status 1)))
          (message "ripgrep search failed with status %s" status))))))

(defun my/search-rg-start-generation (session query)
  "Replace SESSION's process with one argv-only generation for QUERY."
  (setf (my/search-rg-session-generation session)
        (1+ (my/search-rg-session-generation session)))
  (my/search-rg-stop-process session)
  (setf (my/search-rg-session-stopping session) nil
        (my/search-rg-session-tail session) ""
        (my/search-rg-session-candidates session) nil
        (my/search-rg-session-preview-candidate session) nil)
  (let* ((generation (my/search-rg-session-generation session))
         (root (my/search-rg-session-root session))
         (buffer (generate-new-buffer " *my-search-rg*"))
         (default-directory root)
         (command
          (append (my/search-ripgrep-arguments
                   (my/search-rg-session-args session) query)
                  (list "--" root))))
    (setf (my/search-rg-session-buffer session) buffer)
    (condition-case condition
        (setf (my/search-rg-session-process session)
              (make-process
               :name (format "my-search-rg-%d" generation)
               :buffer buffer
               :stderr buffer
               :command command
               :coding 'utf-8-unix
               :connection-type 'pipe
               :noquery t
               :filter
               (lambda (process output)
                 (my/search-rg-filter session generation process output))
               :sentinel
               (lambda (process _event)
                 (my/search-rg-sentinel session generation process))))
      ((error quit)
       (my/search-rg-stop-process session)
       (signal (car condition) (cdr condition))))
  0))

(defun my/search-rg-collection (session query &rest ignored)
  "Start the current SESSION generation for editable QUERY."
  (ignore ignored)
  (if (string-empty-p query)
      (progn
        (setf (my/search-rg-session-generation session)
              (1+ (my/search-rg-session-generation session)))
        (my/search-rg-stop-process session)
        (setf (my/search-rg-session-stopping session) nil
              (my/search-rg-session-tail session) ""
              (my/search-rg-session-candidates session) nil
              (my/search-rg-session-preview-candidate session) nil)
        (my/search-rg-publish session)
        0)
    (my/search-rg-start-generation session query)))

(defun my/search-rg-visit (session display)
  "Visit typed metadata on accepted Ivy DISPLAY."
  (let ((candidate (get-text-property 0 'my/search-rg-candidate display)))
    (unless candidate
      (user-error "No ripgrep match is selected"))
    (find-file (my/search-rg-candidate-file candidate))
    (goto-char (point-min))
    (forward-line (1- (my/search-rg-candidate-line candidate)))
    (move-to-column (1- (my/search-rg-candidate-column candidate)))
    (setf (my/search-rg-session-visited session) t)))

(defun my/search-rg-action (session display)
  "Preview DISPLAY until Ivy exits, then visit it after origin restoration."
  (let ((candidate (get-text-property 0 'my/search-rg-candidate display)))
    (unless candidate
      (user-error "No ripgrep match is selected"))
    (if (eq ivy-exit 'done)
        (my/search-rg-visit session display)
      (my/search-rg-preview session candidate))))

(defun my/search-rg-create-grep-buffer (session)
  "Create a grep-mode buffer from SESSION's typed candidate snapshot."
  (let ((buffer (get-buffer-create "*my-ripgrep*"))
        (root (my/search-rg-session-root session)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (setq default-directory root)
        (dolist (candidate (my/search-rg-session-candidates session))
          (insert
           (format "%s:%d:%d:%s\n"
                   (my/search-rg-candidate-file candidate)
                   (my/search-rg-candidate-line candidate)
                   (my/search-rg-candidate-column candidate)
                   (replace-regexp-in-string
                    "[\n\r]+" "\\\\n" (my/search-rg-candidate-text candidate)))))
        (grep-mode)
        (compilation-parse-errors (point-min) (point-max))))
    (pop-to-buffer buffer)
    (setf (my/search-rg-session-export-buffer session) buffer)
    buffer))

(defun my/search-rg-export ()
  "Exit Ivy and export current repository-owned ripgrep candidates."
  (interactive)
  (let ((session my/search-active-rg-session))
    (unless (and session (my/search-rg-session-active session))
      (user-error "No repository-owned ripgrep search is active"))
    (unless (my/search-rg-session-candidates session)
      (user-error "The ripgrep search has no candidates to export"))
    (ivy-exit-with-action
     (lambda (_candidate)
       (my/search-rg-create-grep-buffer session)))))

(defun my/search-ivy-ripgrep (root initial args)
  "Run the safe local Ivy ripgrep reader below ROOT using INITIAL and ARGS."
  (unless (executable-find "rg")
    (user-error "Required program \"rg\" not found in your path"))
  (require 'ivy)
  (let* ((session
          (make-my/search-rg-session
           :root root
           :args args
           :generation 0
           :tail ""
           :origin-buffer (current-buffer)
           :origin-marker (point-marker)
           :origin-window (selected-window)
           :origin-window-start (window-start)
           :active t))
         (my/search-active-rg-session session))
    (unwind-protect
        (progn
          (minibuffer-with-setup-hook
              (lambda ()
                (setf (my/search-rg-session-minibuffer session)
                      (current-buffer)))
            (ivy-read
             "Ripgrep: "
             (lambda (query &rest ignored)
               (apply #'my/search-rg-collection session query ignored))
             :dynamic-collection t
             :require-match t
             :initial-input initial
             :keymap my/search-rg-map
             :sort nil
             :matcher (lambda (_regexp candidates) candidates)
             :update-fn 'auto
             :action (lambda (display) (my/search-rg-action session display))
             :unwind (lambda () (my/search-rg-restore-origin session))
             :caller 'my/search-ivy-ripgrep))
          (unless (or (my/search-rg-session-visited session)
                      (my/search-rg-session-export-buffer session))
            (my/search-rg-restore-origin session)
            (when (my/search-rg-session-preview-candidate session)
              (my/search-rg-visit
               session
               (my/search-rg-candidate-display
                (my/search-rg-session-preview-candidate session) root)))))
      (unless (or (my/search-rg-session-visited session)
                  (my/search-rg-session-export-buffer session))
        (my/search-rg-restore-origin session))
      (set-marker (my/search-rg-session-origin-marker session) nil)
      (my/search-rg-close-session session))))

(defun my/search-ripgrep (&optional initial)
  "Search project or current root content with the applied completion stack.

INITIAL is passed as one literal process argument to the repository-owned Ivy
reader.  The native Consult route receives the same initial prompt text."
  (interactive)
  (let* ((args (transient-args 'my/search-ripgrep-menu))
         (root (my/search-root args)))
    (if (or (eq my/completion-stack 'native-consult)
            (file-remote-p root))
        (let ((function #'my/search-consult-ripgrep))
          (if (eq my/completion-stack 'ivy-counsel)
              (my/call-with-native-completion function root initial args)
            (funcall function root initial args)))
      (my/search-ivy-ripgrep root initial args))))

(defun my/search-ripgrep-region-or-symbol ()
  "Search region or symbol text with the applied ripgrep implementation."
  (interactive)
  (let ((text (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (thing-at-point 'symbol t))))
    (unless text
      (user-error "No region or symbol at point"))
    (deactivate-mark)
    (my/search-ripgrep text)))

(transient-define-prefix my/search-line-menu ()
  "Configure current-buffer line search for either completion stack."
  :value my/search-line-default-args
  :remember-value '(export save)
  [["Matching"
    ("c" "Case" "--case="
     :choices '("insensitive" "sensitive")
     :always-read t)
    ("o" "Origin" "--origin="
     :choices '("point" "top")
     :always-read t)]
   ["Actions"
    ("RET" "Search lines" my/search-line)]])

(transient-define-prefix my/search-lines-menu ()
  "Configure multi-buffer line search for either completion stack."
  :value my/search-lines-default-args
  :remember-value '(export save)
  [["Matching"
    ("c" "Case" "--case="
     :choices '("insensitive" "sensitive")
     :always-read t)
    ("s" "Scope" "--scope="
     :choices '("all" "project")
     :always-read t)]
   ["Actions"
    ("RET" "Search lines" my/search-lines)]])

(transient-define-prefix my/search-buffer-menu ()
  "Configure buffer selection for either completion stack."
  :value my/search-buffer-default-args
  :remember-value '(export save)
  [["Matching"
    ("c" "Case" "--case="
     :choices '("insensitive" "sensitive")
     :always-read t)
    ("s" "Scope" "--scope="
     :choices '("all" "project")
     :always-read t)]
   ["Actions"
    ("RET" "Select buffer" my/select-buffer)]])

(transient-define-prefix my/search-ripgrep-menu ()
  "Configure ripgrep search for either completion stack."
  :value my/search-ripgrep-default-args
  :remember-value '(export save)
  [["Scope"
    ("r" "Root" "--root="
     :choices '("project" "directory")
     :always-read t)]
   ["Files"
    ("h" "Include hidden files" "--hidden")
    ("i" "Include ignored files" "--no-ignore")
    ("f" "Follow symlinks" "--follow")
    ("g" "Glob" "--glob=" :always-read t)
    ("t" "File type" "--type=" :always-read t)]
   ["Matching"
    ("c" "Case" "--case="
     :choices '("insensitive" "smart" "sensitive")
     :always-read t)
    ("m" "Matching" "--matching="
     :choices '("regexp" "fixed")
     :always-read t)
    ("C" "Context lines" "--context=" :always-read t)]
   ["Actions"
    ("RET" "Search ripgrep" my/search-ripgrep)
    ("w" "Search region or symbol" my/search-ripgrep-region-or-symbol)]])

(provide 'my-search)

;;; my-search.el ends here
