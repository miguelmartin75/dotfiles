;;; my-send-text.el --- Text target delivery and annotation queues -*- lexical-binding: t; -*-

;;; Commentary:

;; Target selection, delivery, replay, split creation, and annotation queues.

;;; Code:

(require 'subr-x)
(require 'tab-bar)

(declare-function ghostel-buffer-list "ghostel")
(declare-function ghostel-create "ghostel" (name action))
(declare-function ghostel-paste-string "ghostel" (text))
(declare-function ghostel-send-key "ghostel" (key &optional modifier))
(declare-function term-sessions-open "term-sessions-frontends" (entry command))
(declare-function term-sessions-send "term-sessions-zmx" (name text))
(declare-function term-sessions--read-existing-session-entry "term-sessions-list" (prompt))

(defconst my/send-text-right-split-action
  '((display-buffer-in-direction)
    (direction . right)
    (window-width . 0.5))
  "Display action for equal-width terminal splits on the right.")

(defun my/send-text-save-last-target (target)
  "Save TARGET as the current tab's last successful text target."
  (let ((tabs
         (mapcar (lambda (tab)
                   (if (eq (car tab) 'current-tab)
                       (let ((properties (cdr tab)))
                         (setf (alist-get 'my/send-text-last-target properties) target)
                         (cons 'current-tab properties))
                     tab))
                 (tab-bar-tabs))))
    (tab-bar-tabs-set tabs)))

(defun my/ghostel-target-live-p (target)
  "Return non-nil when TARGET retains its live Ghostel buffer and process pair."
  (let ((buffer (plist-get target :buffer))
        (process (plist-get target :process)))
    (and (buffer-live-p buffer)
         (memq buffer (ghostel-buffer-list))
         (eq process (get-buffer-process buffer))
         (process-live-p process))))

(defun my/send-text-deliver (target text replay)
  "Deliver TEXT to TARGET, clearing stale object targets during REPLAY."
  (pcase (plist-get target :type)
    ('zmx
     (let ((default-directory (plist-get target :directory)))
       (term-sessions-send (plist-get target :name) (concat text "\r"))))
    ('ghostel
     (require 'ghostel)
     (let ((buffer (plist-get target :buffer)))
       (unless (my/ghostel-target-live-p target)
         (when replay
           (my/send-text-save-last-target nil))
         (user-error "Ghostel target is no longer available"))
       (condition-case error-data
           (with-current-buffer buffer
             (ghostel-paste-string text))
         (error
          (unless (my/ghostel-target-live-p target)
            (when replay
              (my/send-text-save-last-target nil)))
          (signal (car error-data) (cdr error-data))))
       (unless (my/ghostel-target-live-p target)
         (when replay
           (my/send-text-save-last-target nil))
         (user-error "Ghostel target is no longer available"))
       (condition-case error-data
           (with-current-buffer buffer
             (ghostel-send-key "return"))
         (error
          (unless (my/ghostel-target-live-p target)
            (when replay
              (my/send-text-save-last-target nil)))
          (signal (car error-data) (cdr error-data))))
       (unless (my/ghostel-target-live-p target)
         (when replay
           (my/send-text-save-last-target nil))
         (user-error "Ghostel target is no longer available"))))
    ('process
     (let ((buffer (plist-get target :buffer))
           (process (plist-get target :process)))
       (unless (and (buffer-live-p buffer)
                    (process-live-p process)
                    (eq process (get-buffer-process buffer)))
         (when replay
           (my/send-text-save-last-target nil))
         (user-error "Process target is no longer available"))
       (process-send-string process text)))
    ('buffer
     (let ((buffer (plist-get target :buffer)))
       (unless (buffer-live-p buffer)
         (when replay
           (my/send-text-save-last-target nil))
         (user-error "Writable buffer target is no longer available"))
       (with-current-buffer buffer
         (when buffer-read-only
           (user-error "Writable buffer target is now read-only"))
         (insert text))))
    (_
     (user-error "Unknown text target descriptor"))))

(defun my/send-text-to-target (text)
  "Prompt for a target, then deliver TEXT."
  (let ((source-directory default-directory)
        (target-class
         (completing-read
          "Target: "
          '("zmx" "buffer" "ghostty")
          nil t))
        target)
    (pcase target-class
      ("zmx"
       (pcase (completing-read
               "zmx target: "
               '("existing" "create new")
               nil t)
         ("existing"
          (require 'term-sessions-list)
          (let ((entry (term-sessions--read-existing-session-entry "zmx session: ")))
            (setq target (list :type 'zmx
                               :name (plist-get entry :name)
                               :directory (plist-get entry :directory)))))
         ("create new"
          (let ((name (read-string "zmx session name: ")))
            (let ((default-directory source-directory)
                  (display-buffer-overriding-action my/send-text-right-split-action))
              (term-sessions-open
               (list :name name :directory source-directory)
               nil))
            (setq target (list :type 'zmx
                               :name name
                               :directory source-directory))))
         (_
          (user-error "Unknown zmx target selection"))))
      ("buffer"
       (require 'ghostel)
       (let ((ghostel-buffers (ghostel-buffer-list))
             candidates
             ambiguous-buffers)
         (dolist (buffer (buffer-list))
           (let ((process (get-buffer-process buffer)))
             (cond
              ((memq buffer ghostel-buffers)
               (when (process-live-p process)
                 (push (cons (buffer-name buffer)
                             (list :type 'ghostel
                                   :buffer buffer
                                   :process process))
                       candidates)))
              ((process-live-p process)
               (with-current-buffer buffer
                 (push (cons (buffer-name buffer)
                             (list :type 'process
                                   :buffer buffer
                                   :process process))
                       candidates)
                 (unless buffer-read-only
                   (push buffer ambiguous-buffers))))
              (t
               (with-current-buffer buffer
                 (unless buffer-read-only
                   (push (cons (buffer-name buffer)
                               (list :type 'buffer :buffer buffer))
                         candidates)))))))
         (setq candidates (nreverse candidates))
         (unless candidates
           (user-error "No buffers can accept input"))
         (let ((name (completing-read "Buffer: " candidates nil t)))
           (setq target (alist-get name candidates nil nil #'string=))
           (when (memq (plist-get target :buffer) ambiguous-buffers)
             (pcase (completing-read
                     "Buffer operation: "
                     '("send raw text" "insert at point")
                     nil t)
               ("send raw text")
               ("insert at point"
                (setq target (list :type 'buffer
                                   :buffer (plist-get target :buffer))))
               (_
                (user-error "Unknown buffer operation")))))))
      ("ghostty"
       (require 'ghostel)
       (let (candidates)
         (dolist (buffer (ghostel-buffer-list))
           (let ((target (list :type 'ghostel
                               :buffer buffer
                               :process (get-buffer-process buffer))))
             (when (my/ghostel-target-live-p target)
               (push (cons (format "buffer: %s" (buffer-name buffer)) target)
                     candidates))))
         (setq candidates
               (append (nreverse candidates)
                       (list (cons "create new" 'create-new))))
         (let ((selection (completing-read "Ghostty: " candidates nil t)))
           (if (string= selection "create new")
               (let ((name (read-string "Ghostty buffer name (optional): "))
                     buffer)
                 (let ((default-directory source-directory))
                   (setq buffer
                         (ghostel-create name my/send-text-right-split-action)))
                 (setq target (list :type 'ghostel
                                    :buffer buffer
                                    :process (get-buffer-process buffer)))
                 (unless (my/ghostel-target-live-p target)
                   (user-error "Created Ghostty buffer cannot accept input")))
             (setq target (alist-get selection candidates nil nil #'string=))))))
      (_
       (user-error "Unknown text target selection")))
    (my/send-text-deliver target text nil)
    (my/send-text-save-last-target target)))

(defun my/send-text-send-to-last-target (text)
  "Replay the current tab's last successful target with TEXT, or choose one."
  (let (target)
    (dolist (tab (tab-bar-tabs))
      (when (eq (car tab) 'current-tab)
        (setq target (alist-get 'my/send-text-last-target (cdr tab)))))
    (if target
        (my/send-text-deliver target text t)
      (my/send-text-to-target text))))

(defun my/send-region-or-buffer ()
  "Choose a target for the active region or accessible buffer contents."
  (interactive)
  (my/send-text-to-target
   (if (use-region-p)
       (buffer-substring-no-properties (region-beginning) (region-end))
     (buffer-substring-no-properties (point-min) (point-max)))))

(defun my/send-region-or-buffer-to-last-target ()
  "Replay active text to this tab's last target, or choose one when absent."
  (interactive)
  (my/send-text-send-to-last-target
   (if (use-region-p)
       (buffer-substring-no-properties (region-beginning) (region-end))
     (buffer-substring-no-properties (point-min) (point-max)))))

(defun my/create-ghostel-terminal-in-split (&optional name directory)
  "Create a Ghostel terminal in a right-side split and save it for this tab."
  (interactive
   (let ((directory default-directory))
     (list (read-string "Ghostel buffer name (optional): ") directory)))
  (unless directory
    (setq directory default-directory))
  (require 'ghostel)
  (let* ((default-directory directory)
         (buffer
          (ghostel-create name
                          my/send-text-right-split-action))
         (target (list :type 'ghostel
                       :buffer buffer
                       :process (get-buffer-process buffer))))
    (unless (my/ghostel-target-live-p target)
      (user-error "Created Ghostel buffer cannot accept input"))
    (my/send-text-save-last-target target)))

(defun my/open-or-create-zmx-session-in-split (&optional name command directory)
  "Open or create a zmx session in a right-side split and save it for this tab."
  (interactive
   (let ((directory default-directory)
         (name (read-string "zmx session name: "))
         command)
     (when current-prefix-arg
       (setq command (read-string "Command for new session: ")))
     (list name command directory)))
  (unless directory
    (setq directory default-directory))
  (let ((default-directory directory)
        (display-buffer-overriding-action my/send-text-right-split-action))
    (term-sessions-open (list :name name :directory directory) command)
    (my/send-text-save-last-target
     (list :type 'zmx :name name :directory directory))))

(defvar my/annotations nil
  "Queued source annotations awaiting explicit target selection.")

(defun my/annotate-region (begin end annotation)
  "Queue the region from BEGIN to END with ANNOTATION."
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end)
             (read-string "Annotation: "))
     (user-error "Select a region to annotate")))
  (push (list :source (or buffer-file-name (buffer-name))
              :start-line (line-number-at-pos begin t)
              :end-line (line-number-at-pos (max begin (1- end)) t)
              :mode major-mode
              :annotation annotation
              :text (buffer-substring-no-properties begin end))
        my/annotations)
  (message "Queued annotation %d" (length my/annotations)))

(defun my/annotate-send-all (request)
  "Send queued annotations with optional overall REQUEST."
  (interactive (list (read-string "Overall request (optional): ")))
  (unless my/annotations
    (user-error "No annotations are queued"))
  (let ((prompt "# Review annotations\n"))
    (unless (string-empty-p request)
      (setq prompt (concat prompt "\n## Overall request\n\n" request "\n")))
    (dolist (item (reverse my/annotations))
      (let ((text (plist-get item :text))
            (fence "```")
            (start 0))
        (while (string-match "`+" text start)
          (setq fence
                (make-string (max (length fence)
                                  (1+ (length (match-string 0 text)))) ?`)
                start (match-end 0)))
        (setq prompt
              (concat prompt
                      "\n## " (plist-get item :source)
                      ":" (number-to-string (plist-get item :start-line))
                      "-" (number-to-string (plist-get item :end-line))
                      " (" (symbol-name (plist-get item :mode)) ")\n\n"
                      (plist-get item :annotation) "\n\n" fence "\n"
                      text "\n" fence "\n"))))
    (my/send-text-to-target prompt)
    (setq my/annotations nil)))

(provide 'my-send-text)

;;; my-send-text.el ends here
