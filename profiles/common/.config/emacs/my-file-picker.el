;;; my-file-picker.el --- Toggle hierarchical and recursive file pickers -*- lexical-binding: t; -*-

(require 'files)
(require 'project)
(require 'subr-x)
(require 'tramp)

(declare-function consult-fd "consult" (&optional dir initial))
(declare-function consult-find "consult" (&optional dir initial))

(defvar consult-async-split-style)
(defvar consult-async-split-styles-alist)
(defvar consult-fd-args)
(defvar consult-find-args)

(defvar my/file-picker-transaction nil
  "Dynamically bound cell containing the selected file for one picker stack.")

(defvar-local my/file-picker-kind nil
  "Discovery kind of the current file picker minibuffer.")

(defvar-local my/file-picker-root nil
  "Unabbreviated root of the current file picker minibuffer.")

(defvar my/file-picker-minibuffer-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-c C-r" #'my/file-picker-toggle)
    map)
  "Keymap added locally to active file picker minibuffers.")

(defconst my/file-picker-local-fd-args
  '("fd" "--full-path" "--color=never" "--hidden" "--no-ignore"
    "--follow" "--type" "f" "--exclude" ".git"))

(defconst my/file-picker-remote-fd-args
  '("fd" "--full-path" "--color=never" "--hidden" "--no-ignore"
    "--type" "f" "--exclude" ".git"))

(defconst my/file-picker-remote-find-args
  '("find" "." "-type" "d" "-name" ".git" "-prune" "-name" ""
    "-o" "-type" "f"))

(defun my/file-picker-setup (kind root)
  "Configure the current minibuffer for KIND below ROOT."
  (setq-local my/file-picker-kind kind
              my/file-picker-root root)
  (use-local-map
   (make-composed-keymap my/file-picker-minibuffer-map (current-local-map))))

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
  "Read a file hierarchically below ROOT with literal INITIAL text."
  (let ((read-root (if (and initial (file-name-absolute-p initial))
                       (file-name-directory initial)
                     root))
        (read-initial (if (and initial (file-name-absolute-p initial))
                          (file-name-nondirectory initial)
                        initial)))
    (minibuffer-with-setup-hook
        (lambda () (my/file-picker-setup 'hierarchical root))
      (read-file-name "Find file: " read-root nil nil read-initial))))

(defun my/file-picker-recursive-session (root initial)
  "Recursively select and open a file below ROOT with INITIAL query."
  (let ((remote (file-remote-p root)))
    (if remote
        (let ((default-directory root))
          (if (executable-find "fd" t)
              (let ((consult-fd-args my/file-picker-remote-fd-args))
                (minibuffer-with-setup-hook
                    (lambda () (my/file-picker-setup 'recursive root))
                  (consult-fd root initial)))
            (let ((consult-find-args my/file-picker-remote-find-args))
              (minibuffer-with-setup-hook
                  (lambda () (my/file-picker-setup 'recursive root))
                (consult-find root initial)))))
      (let ((consult-fd-args my/file-picker-local-fd-args))
        (minibuffer-with-setup-hook
            (lambda () (my/file-picker-setup 'recursive root))
          (consult-fd root initial))))))

(defun my/file-picker-refresh (buffer)
  "Refresh completion candidates in the active minibuffer BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (minibuffer-completion-help))))

(defun my/file-picker-toggle ()
  "Suspend the active file picker and enter its other discovery mode."
  (interactive)
  (unless (and (minibufferp) my/file-picker-kind my/file-picker-root)
    (user-error "No file picker is active"))
  (let ((outer-buffer (current-buffer))
        (outer-input (minibuffer-contents-no-properties))
        (root my/file-picker-root)
        (kind my/file-picker-kind)
        (enable-recursive-minibuffers t))
    (condition-case nil
        (if (eq kind 'hierarchical)
            (progn
              (when (and (string-match
                          "\\`/\\([^/:]+\\):" outer-input)
                         (assoc-string (match-string 1 outer-input)
                                       tramp-methods)
                         (or (not (file-remote-p outer-input))
                             (string-empty-p
                              (or (tramp-file-name-host
                                   (tramp-dissect-file-name outer-input t))
                                  ""))))
                (user-error "Complete the remote host before recursive search"))
              (let* ((directory (file-name-directory outer-input))
                     (nested-root (if directory
                                      (if (file-name-absolute-p directory)
                                          directory
                                        (expand-file-name directory root))
                                    root))
                     (leaf (file-name-nondirectory outer-input))
                     (consult-async-split-style nil)
                     (buffer (my/file-picker-recursive-session
                              nested-root (regexp-quote leaf)))
                     (selected (buffer-file-name buffer)))
                (setcar my/file-picker-transaction selected)
                (abort-recursive-edit)))
          (let* ((initial (if (eq kind 'project)
                              outer-input
                            (my/file-picker-literal-query outer-input)))
                 (selected (my/file-picker-hierarchical-session root initial)))
            (find-file selected)
            (setcar my/file-picker-transaction selected)
            (abort-recursive-edit)))
      (quit
       (if (car my/file-picker-transaction)
           (abort-recursive-edit)
         (my/file-picker-refresh outer-buffer))))))

(defun my/find-file (&optional root initial)
  "Open a file hierarchically below ROOT with optional INITIAL leaf text."
  (interactive)
  (let ((my/file-picker-transaction (list nil)))
    (condition-case error-data
        (find-file (my/file-picker-hierarchical-session
                    (or root default-directory) initial))
      (quit
       (unless (car my/file-picker-transaction)
         (signal (car error-data) (cdr error-data)))))))

(defun my/find-file-recursive (root &optional initial)
  "Recursively select and open a file below ROOT with optional INITIAL query."
  (let ((my/file-picker-transaction (list nil)))
    (condition-case error-data
        (let ((buffer (my/file-picker-recursive-session root initial)))
          (setcar my/file-picker-transaction (buffer-file-name buffer))
          buffer)
      (quit
       (if (car my/file-picker-transaction)
           (get-file-buffer (car my/file-picker-transaction))
         (signal (car error-data) (cdr error-data)))))))

(defun my/find-file-recursive-root ()
  "Recursively search all files below the project or default directory."
  (interactive)
  (let ((project (project-current)))
    (my/find-file-recursive
     (if project (project-root project) default-directory))))

(defun my/find-file-project ()
  "Select and open a project file with project picker toggle context."
  (interactive)
  (let* ((project (project-current t))
         (root (project-root project))
         (project-read-file-name-function #'project--read-file-absolute)
         (my/file-picker-transaction (list nil)))
    (condition-case error-data
        (minibuffer-with-setup-hook
            (lambda () (my/file-picker-setup 'project root))
          (project-find-file))
      (quit
       (unless (car my/file-picker-transaction)
         (signal (car error-data) (cdr error-data)))))))

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
