;;; my-send-text.el --- Text target delivery and annotation queues -*- lexical-binding: t; -*-

;;; Commentary:

;; Target selection, delivery, replay, split creation, and annotation queues.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'tab-bar)

(declare-function ghostel-buffer-list "ghostel")
(declare-function ghostel-create "ghostel" (name action))
(declare-function ghostel-paste-string "ghostel" (text))
(declare-function ghostel-send-key "ghostel" (key &optional modifier))
(declare-function ghostel-semi-char-mode "ghostel")
(declare-function evil-ghostel-insert "evil-ghostel")
(declare-function term-sessions-open "term-sessions-frontends" (entry &optional command))
(declare-function term-sessions-send "term-sessions-zmx" (name text))
(declare-function term-sessions--read-session-entry "term-sessions-frontends"
                  (&optional prompt require-existing))

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
       (require 'term-sessions-list)
       (let* ((default-directory source-directory)
              (entry (term-sessions--read-session-entry "zmx session: " nil)))
         (unless (plist-member entry :session)
           (let ((display-buffer-overriding-action my/send-text-right-split-action))
             (term-sessions-open entry nil)
             (let ((buffer (current-buffer)))
               (with-current-buffer buffer
                 (ghostel-semi-char-mode)
                 (evil-ghostel-insert)))))
         (setq target (list :type 'zmx
                            :name (plist-get entry :name)
                            :directory (plist-get entry :directory)))))
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

(defun my/markdown-fenced-code-body ()
  "Return the complete fenced Markdown code body at point.
Signal a user error when point is not in a complete fenced code block."
  (cond
   ((eq major-mode 'markdown-ts-mode)
    (let* ((node (treesit-node-at (point) 'markdown))
           (block
            (and node
                 (treesit-parent-until
                  node
                  (lambda (candidate)
                    (string= (treesit-node-type candidate)
                             "fenced_code_block"))
                  t))))
      (unless block
        (user-error "Point is not in a fenced Markdown code block"))
      (let (delimiters content)
        (dolist (child (treesit-node-children block))
          (cond
           ((string= (treesit-node-type child)
                     "fenced_code_block_delimiter")
            (push child delimiters))
           ((string= (treesit-node-type child) "code_fence_content")
            (setq content child))))
        (unless (= (length delimiters) 2)
          (user-error "Markdown fenced code block is incomplete"))
        (if content
            (buffer-substring-no-properties (treesit-node-start content)
                                            (treesit-node-end content))
          ""))))
   ((derived-mode-p 'markdown-mode)
    (let ((bounds (markdown-get-enclosing-fenced-block-construct)))
      (unless bounds
        (user-error "Point is not in a complete fenced Markdown code block"))
      (save-excursion
        (goto-char (car bounds))
        (unless (looking-at "^[ \\t]*\\(`\\{3,\\}\\|~\\{3,\\}\\).*$")
          (user-error "Point is not in a backtick or tilde fenced code block"))
        (let* ((fence (match-string-no-properties 1))
               (fence-character (aref fence 0))
               (fence-length (length fence))
               (content-start (progn (forward-line 1) (point)))
               (closing-regexp
                (format "^[ \\t]*%c\\{%d,\\}[ \\t]*$"
                        fence-character fence-length))
               closing)
          (while (and (< (point) (cadr bounds)) (not closing))
            (if (looking-at closing-regexp)
                (setq closing (line-beginning-position))
              (forward-line 1)))
          (unless closing
            (user-error "Markdown fenced code block is incomplete"))
          (buffer-substring-no-properties content-start closing)))))
   (t
    (user-error "Not in a Markdown buffer"))))

(defun my/send-markdown-fenced-code-to-last-target ()
  "Send fenced Markdown code to the last terminal target.
Execution occurs in the target terminal's current shell or REPL and needs a
suitable interpreter.  No results are written back to the Markdown file."
  (interactive)
  (my/send-text-send-to-last-target (my/markdown-fenced-code-body)))

(defun my/send-markdown-fenced-code-to-target ()
  "Choose a terminal target and send fenced Markdown code to it.
Execution occurs in the target terminal's current shell or REPL and needs a
suitable interpreter.  No results are written back to the Markdown file."
  (interactive)
  (my/send-text-to-target (my/markdown-fenced-code-body)))

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

(defun my/open-or-create-zmx-session-in-split (&optional entry command)
  "Open or create zmx session ENTRY in a split and save it for this tab."
  (interactive
   (let ((directory default-directory)
         entry
         command)
     (require 'term-sessions-list)
     (let ((default-directory directory))
       (setq entry (term-sessions--read-session-entry "zmx session: " nil)))
     (when (and current-prefix-arg (not (plist-member entry :session)))
       (setq command (read-string "Command for new session: ")))
     (list entry command)))
  (let ((default-directory (plist-get entry :directory))
        (display-buffer-overriding-action my/send-text-right-split-action))
    (term-sessions-open entry command)
    (let ((buffer (current-buffer)))
      (with-current-buffer buffer
        (ghostel-semi-char-mode)
        (evil-ghostel-insert)))
    (my/send-text-save-last-target
     (list :type 'zmx
           :name (plist-get entry :name)
           :directory (plist-get entry :directory)))))

(defvar my/annotations nil
  "Queued source annotations awaiting explicit target selection.")

(defvar my/annotation-next-id 0
  "Next session-local identifier for queued source annotations.")

(defun my/annotate-region (begin end annotation)
  "Queue the region from BEGIN to END with ANNOTATION."
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end)
             (read-string "Annotation: "))
     (user-error "Select a region to annotate")))
  (push (list :source (or buffer-file-name (buffer-name))
              :id (cl-incf my/annotation-next-id)
              :start-line (line-number-at-pos begin t)
              :end-line (line-number-at-pos (max begin (1- end)) t)
              :mode major-mode
              :annotation annotation
              :text (buffer-substring-no-properties begin end))
        my/annotations)
  (message "Queued annotation %d" (length my/annotations)))

(defun my/annotate-current-hunk (annotation)
  "Queue the current diff-hl hunk with ANNOTATION."
  (interactive (list (read-string "Annotation: ")))
  (let (begin end patch text)
    (save-mark-and-excursion
      (diff-hl-mark-hunk)
      (setq begin (point)
            end (mark)
            text (buffer-substring-no-properties begin end))
      (let ((hunk (diff-hl-show-hunk-buffer)))
        (with-current-buffer (car hunk)
          (let ((hunk-begin (point-min))
                (hunk-end (point-max)))
            (save-restriction
              (widen)
              (save-excursion
                (goto-char hunk-begin)
                (re-search-backward "^@@" nil t)
                (setq patch
                      (buffer-substring-no-properties (point) hunk-end))))))))
    (push (list :source (or buffer-file-name (buffer-name))
                :id (cl-incf my/annotation-next-id)
                :start-line (line-number-at-pos begin t)
                :end-line (line-number-at-pos (max begin (1- end)) t)
                :mode major-mode
                :annotation annotation
                :patch patch
                :text text)
          my/annotations)
    (message "Queued annotation %d" (length my/annotations))))

(defun my/annotate-send-all (request)
  "Send queued annotations with optional overall REQUEST."
  (interactive (list (read-string "Overall request (optional): ")))
  (unless my/annotations
    (user-error "No annotations are queued"))
  (let ((prompt "# Review annotations\n"))
    (unless (string-empty-p request)
      (setq prompt (concat prompt "\n## Overall request\n\n" request "\n")))
    (dolist (item (reverse my/annotations))
      (let ((patch (plist-get item :patch))
            (text (plist-get item :text)))
        (setq prompt
              (concat prompt
                      "\n## " (plist-get item :source)
                      ":" (number-to-string (plist-get item :start-line))
                      "-" (number-to-string (plist-get item :end-line))
                      " (" (symbol-name (plist-get item :mode)) ")\n\n"
                      (plist-get item :annotation) "\n\n"))
        (dolist (section (append (and patch (list (list patch "diff")))
                                 (list (list text ""))))
          (let ((content (car section))
                (language (cadr section))
                (fence "```")
                (start 0))
            (while (string-match "`+" content start)
              (setq fence
                    (make-string (max (length fence)
                                      (1+ (length (match-string 0 content)))) ?`)
                    start (match-end 0)))
            (setq prompt (concat prompt fence language "\n" content "\n" fence "\n"))
            (when (string= language "diff")
              (setq prompt (concat prompt "\n")))))))
    (my/send-text-to-target prompt)
    (setq my/annotations nil)))

(define-derived-mode my/annotations-mode special-mode "Review Annotations"
  "Major mode for reviewing queued source annotations.")

(defconst my/annotations-buffer-name "*Review Annotations*"
  "Buffer name for the annotation review queue.")

(defun my/annotations-render ()
  "Render `my/annotations' in the current review buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (if my/annotations
        (dolist (item (reverse my/annotations))
          (let ((begin (point))
                (patch (plist-get item :patch)))
            (insert (format "[%s] %s:%d-%d queued\n"
                            (plist-get item :id)
                            (plist-get item :source)
                            (plist-get item :start-line)
                            (plist-get item :end-line)))
            (insert "Note: " (plist-get item :annotation) "\n")
            (when patch
              (insert "\nPatch:\n" patch "\n"))
            (insert "\nSource:\n" (plist-get item :text) "\n\n")
            (add-text-properties begin (point)
                                 (list 'my/annotation-id
                                       (plist-get item :id)))))
      (insert "No annotations are queued.\n"))
    (goto-char (point-min))))

(defun my/annotations-current-item ()
  "Return the queued annotation rendered at point."
  (let ((id (get-text-property (point) 'my/annotation-id)))
    (or (cl-find id my/annotations :key (lambda (item) (plist-get item :id)))
        (user-error "No annotation at point"))))

(defun my/annotations-next ()
  "Move to the next annotation in the review queue."
  (interactive)
  (let ((id (get-text-property (point) 'my/annotation-id))
        (position (point)))
    (while (and (< position (point-max))
                (or (not (get-text-property position 'my/annotation-id))
                    (equal (get-text-property position 'my/annotation-id) id)))
      (setq position
            (next-single-property-change position 'my/annotation-id
                                         nil (point-max))))
    (if (< position (point-max))
        (goto-char position)
      (user-error "No next annotation"))))

(defun my/annotations-previous ()
  "Move to the previous annotation in the review queue."
  (interactive)
  (let ((id (get-text-property (point) 'my/annotation-id))
        (position (point))
        result)
    (while (and (> position (point-min)) (not result))
      (setq position
            (previous-single-property-change position 'my/annotation-id
                                             nil (point-min)))
      (when (and (get-text-property position 'my/annotation-id)
                 (not (equal (get-text-property position 'my/annotation-id) id)))
        (setq result position)))
    (if result
        (goto-char result)
      (user-error "No previous annotation"))))

(defun my/annotations-visit ()
  "Visit the source location for the annotation at point."
  (interactive)
  (let* ((item (my/annotations-current-item))
         (source (plist-get item :source))
         (buffer (get-buffer source)))
    (if buffer
        (pop-to-buffer buffer)
      (find-file source))
    (goto-char (point-min))
    (forward-line (1- (plist-get item :start-line)))))

(defun my/annotations-edit ()
  "Edit the note for the annotation at point."
  (interactive)
  (let ((item (my/annotations-current-item)))
    (setf (plist-get item :annotation)
          (read-string "Annotation: " (plist-get item :annotation)))
    (my/annotations-refresh)))

(defun my/annotations-delete ()
  "Delete the annotation at point from the queue."
  (interactive)
  (let ((item (my/annotations-current-item)))
    (setq my/annotations (delq item my/annotations))
    (my/annotations-render)
    (message "Deleted annotation")))

(defun my/annotations-refresh ()
  "Refresh the review queue while preserving the current annotation."
  (interactive)
  (let ((id (plist-get (my/annotations-current-item) :id)))
    (my/annotations-render)
    (while (and (< (point) (point-max))
                (not (equal (get-text-property (point) 'my/annotation-id) id)))
      (goto-char (next-single-property-change
                  (point) 'my/annotation-id nil (point-max))))))

(defun my/annotations-send ()
  "Prompt for an overall request and explicitly send the review queue."
  (interactive)
  (call-interactively #'my/annotate-send-all)
  (my/annotations-render))

(defun my/annotations-show ()
  "Display the queued source annotations for review."
  (interactive)
  (let ((buffer (get-buffer-create my/annotations-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'my/annotations-mode)
        (my/annotations-mode))
      (my/annotations-render))
    (pop-to-buffer buffer)))

(keymap-set my/annotations-mode-map "n" #'my/annotations-next)
(keymap-set my/annotations-mode-map "p" #'my/annotations-previous)
(keymap-set my/annotations-mode-map "RET" #'my/annotations-visit)
(keymap-set my/annotations-mode-map "e" #'my/annotations-edit)
(keymap-set my/annotations-mode-map "d" #'my/annotations-delete)
(keymap-set my/annotations-mode-map "g" #'my/annotations-refresh)
(keymap-set my/annotations-mode-map "s" #'my/annotations-send)
(keymap-set my/annotations-mode-map "q" #'quit-window)

(provide 'my-send-text)

;;; my-send-text.el ends here
