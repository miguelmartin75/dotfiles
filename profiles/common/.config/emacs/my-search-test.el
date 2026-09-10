;;; my-search-test.el --- Behavioral tests for stack-aware search -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'my-search)

(defconst my/search-test-directory
  (file-name-directory (expand-file-name (or load-file-name buffer-file-name)))
  "Directory containing the search module and tests.")

(defvar my/completion-stack)
(defvar consult-ripgrep-args)

(ert-deftest my/search-dispatches-with-explicit-case-origin-and-scope ()
  (dolist (case '((native-consult "insensitive" "point" consult nil t)
                  (native-consult "sensitive" "top" consult t nil)
                  (ivy-counsel "insensitive" "point" swiper nil t)
                  (ivy-counsel "sensitive" "top" swiper t nil)))
    (with-temp-buffer
      (insert "first\nsecond\nthird\n")
      (goto-char (point-max))
      (let ((my/completion-stack (nth 0 case))
            observed)
        (cl-letf (((symbol-function 'transient-args)
                   (lambda (&rest ignored)
                     (ignore ignored)
                     (list (concat "--case=" (nth 1 case))
                           (concat "--origin=" (nth 2 case)))))
                  ((symbol-function 'consult-line)
                   (lambda (&rest ignored)
                     (ignore ignored)
                     (setq observed
                           (list 'consult consult-line-start-from-top
                                 case-fold-search completion-ignore-case
                                 (point)))))
                  ((symbol-function 'swiper-isearch)
                   (lambda (&rest ignored)
                     (ignore ignored)
                     (setq observed
                           (list 'swiper (eq (point) (point-min))
                                 case-fold-search completion-ignore-case
                                 ivy-case-fold-search-default)))))
          (my/search-line))
        (pcase (nth 3 case)
          ('consult
           (should (equal observed
                          (list 'consult (nth 4 case) (nth 5 case)
                                (nth 5 case) (point-max)))))
          ('swiper
           (should (equal observed
                          (list 'swiper (nth 4 case) (nth 5 case)
                                (nth 5 case)
                                (if (nth 5 case) t nil))))))))
  (dolist (case '((native-consult "insensitive" consult-buffer t)
                  (ivy-counsel "sensitive" ivy-switch-buffer nil)))
    (let ((my/completion-stack (nth 0 case))
          observed)
      (cl-letf (((symbol-function 'transient-args)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   (list (concat "--case=" (nth 1 case)) "--scope=all")))
                ((symbol-function 'consult-buffer)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   (setq observed
                         (list 'consult-buffer completion-ignore-case
                               ivy-case-fold-search-default))))
                ((symbol-function 'ivy-switch-buffer)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   (setq observed
                         (list 'ivy-switch-buffer completion-ignore-case
                               ivy-case-fold-search-default)))))
        (my/select-buffer))
      (should (equal observed
                     (list (nth 2 case) (nth 3 case) (nth 3 case))))))
  (dolist (case '((native-consult consult-project-buffer)
                  (ivy-counsel select-project-buffer)))
    (let ((my/completion-stack (car case))
          observed)
      (cl-letf (((symbol-function 'transient-args)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   '("--case=insensitive" "--scope=project")))
                ((symbol-function 'consult-project-buffer)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   (setq observed 'consult-project-buffer)))
                ((symbol-function 'my/select-project-buffer)
                 (lambda ()
                   (setq observed 'select-project-buffer))))
        (my/select-buffer))
      (should (eq observed (nth 1 case)))))
  (dolist (case '((native-consult consult)
                  (ivy-counsel swiper)))
    (let ((my/completion-stack (nth 0 case))
          observed)
      (cl-letf (((symbol-function 'transient-args)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   '("--case=sensitive" "--scope=all")))
                ((symbol-function 'consult-line-multi)
                 (lambda (&rest arguments)
                   (setq observed
                         (list 'consult arguments case-fold-search
                               completion-ignore-case))))
                ((symbol-function 'swiper-all)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   (setq observed
                         (list 'swiper case-fold-search completion-ignore-case
                               ivy-case-fold-search-default)))))
        (my/search-lines))
      (if (eq (nth 1 case) 'consult)
          (should (equal observed '(consult (t) nil nil)))
        (should (equal observed '(swiper nil nil nil))))))
  (dolist (stack '(native-consult ivy-counsel))
    (let ((my/completion-stack stack)
          adapter-called
          observed)
      (cl-letf (((symbol-function 'transient-args)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   '("--case=insensitive" "--scope=project")))
                ((symbol-function 'my/search-project-buffers)
                 (lambda () '(first-buffer second-buffer)))
                ((symbol-function 'my/search-consult-lines)
                 (lambda (buffers args)
                   (setq observed (list buffers args))))
                ((symbol-function 'my/call-with-native-completion)
                 (lambda (function &rest arguments)
                   (setq adapter-called t)
                   (apply function arguments))))
        (my/search-lines))
      (should (equal observed
                     '((first-buffer second-buffer)
                       ("--case=insensitive" "--scope=project"))))
      (should (eq adapter-called (eq stack 'ivy-counsel)))))
  (dolist (case '((native-consult consult)
                  (ivy-counsel ivy)))
    (let ((my/completion-stack (car case))
          observed)
      (cl-letf (((symbol-function 'transient-args)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   my/search-ripgrep-default-args))
                ((symbol-function 'my/search-root)
                 (lambda (&rest ignored)
                   (ignore ignored)
                   "/tmp/my-search-root/"))
                ((symbol-function 'file-remote-p)
                 (lambda (&rest ignored) (ignore ignored) nil))
                ((symbol-function 'my/search-consult-ripgrep)
                 (lambda (&rest arguments)
                   (setq observed (cons 'consult arguments))))
                ((symbol-function 'my/search-ivy-ripgrep)
                 (lambda (&rest arguments)
                   (setq observed (cons 'ivy arguments)))))
        (my/search-ripgrep "seed"))
      (should (equal observed
                     (list (nth 1 case) "/tmp/my-search-root/" "seed"
                           my/search-ripgrep-default-args)))))))

(ert-deftest my/completion-stack-consult-source-uses-live-public-buffers ()
  (let ((first (generate-new-buffer " *completion source first*"))
        (second (generate-new-buffer " *completion source second*")))
    (unwind-protect
        (let* ((buffers (buffer-list))
               (items (funcall (plist-get my/consult-live-buffer-source :items))))
          (should (eq (plist-get my/consult-live-buffer-source :action)
                      #'switch-to-buffer))
          (should (equal (mapcar #'car items)
                         (mapcar #'buffer-name buffers)))
          (should (equal (mapcar #'cdr items) buffers)))
      (kill-buffer first)
      (kill-buffer second))))

(ert-deftest my/search-native-ripgrep-seeded-multiline-preserves-seed-and-args ()
  (let* ((my/completion-stack 'native-consult)
         (root "/tmp/my-search-root/")
         (args '("--root=project" "--hidden" "--no-ignore"
                 "--case=insensitive" "--matching=regexp" "--context=0"))
         (initial "first line\nsecond line")
         observed)
    (cl-letf (((symbol-function 'transient-args)
               (lambda (&rest ignored)
                 (ignore ignored)
                 args))
              ((symbol-function 'my/search-root)
               (lambda (&rest ignored)
                 (ignore ignored)
                 root))
              ((symbol-function 'file-remote-p)
               (lambda (&rest ignored)
                 (ignore ignored)
                 nil))
              ((symbol-function 'consult-ripgrep)
               (lambda (directory query)
                 (setq observed
                       (list directory query consult-ripgrep-args)))))
      (my/search-ripgrep initial))
    (should (equal observed
                   (list root initial
                         '(
                           "rg" "--null" "--line-buffered" "--color=never"
                           "--max-columns=1000" "--path-separator" "/"
                           "--no-heading" "--with-filename" "--line-number"
                           "--search-zip" "--hidden" "--no-ignore"
                           "--ignore-case" "--context" (list "0")
                           "--multiline"))))))

(ert-deftest my/search-consult-ripgrep-keeps-spaced-glob-as-one-argv-value ()
  (let* ((glob "folder name/*.el")
         (consult-args
          (my/search-consult-ripgrep-arguments
           (list "--root=project" (concat "--glob=" glob)
                 "--type=elisp" "--context=2")))
         (argv
          (append
           (apply #'append
                  (mapcar (lambda (argument)
                            (if (stringp argument)
                                (split-string-and-unquote argument)
                              (ensure-list (eval argument 'lexical))))
                          consult-args))
           '("-e" "needle" "/tmp/my-search-root/"))))
    (should (= (cl-count glob argv :test #'string-equal) 1))
    (let ((glob-index (cl-position "--glob" argv :test #'string-equal)))
      (should (string-equal (nth (1+ glob-index) argv) glob)))))

(ert-deftest my/search-project-candidates-map-public-buffers-and-files ()
  (let* ((root (file-name-as-directory (make-temp-file "my-search-project-" t)))
         (open-file (expand-file-name "notes.org" root))
         (other-file (expand-file-name "todo.org" root))
         (open-buffer (generate-new-buffer "notes.org"))
         (scratch-buffer (generate-new-buffer "notes.org"))
         candidates)
    (unwind-protect
        (progn
          (with-current-buffer open-buffer
            (setq buffer-file-name open-file))
          (cl-letf (((symbol-function 'project-current)
                     (lambda (&rest ignored) (ignore ignored) 'project))
                    ((symbol-function 'project-root)
                     (lambda (&rest ignored) (ignore ignored) root))
                    ((symbol-function 'project-buffers)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       (list open-buffer scratch-buffer)))
                    ((symbol-function 'project-files)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       (list "notes.org" other-file))))
            (setq candidates (my/search-project-buffer-candidates)))
          (should (eq (cdr (assoc "notes.org (buffer)" candidates)) open-buffer))
          (should (eq (cdr (assoc (format "%s (buffer)" (buffer-name scratch-buffer))
                                  candidates))
                      scratch-buffer))
          (should (equal (cdr (assoc "todo.org" candidates)) other-file))
          (should (= (length candidates)
                     (length (delete-dups (mapcar #'car candidates))))))
      (kill-buffer open-buffer)
      (kill-buffer scratch-buffer)
      (delete-directory root t))))

(ert-deftest my/search-rg-argv-keeps-literal-query-and-roots ()
  (let ((root "/tmp/my search root/")
        command)
    (dolist (case '(("regexp spaces" "two words" "regexp" "insensitive")
                    ("fixed punctuation" "[a-z]+(thing)?" "fixed" "smart")
                    ("leading hyphen" "--not-an-option" "regexp" "sensitive")
                    ("embedded separator" "first -- second" "fixed" "insensitive")
                    ("multiline" "first line\nsecond line" "regexp" "smart")))
      (let* ((query (nth 1 case))
             (args (list "--root=project" "--hidden" "--no-ignore" "--follow"
                         (concat "--case=" (nth 3 case))
                         (concat "--matching=" (nth 2 case))
                         "--glob=*.el" "--type=elisp" "--context=2"))
             (session (make-my/search-rg-session
                       :root root :args args :generation 0 :tail "" :active t))
             (my/search-active-rg-session session)
             (case-argument (pcase (nth 3 case)
                              ("sensitive" "--case-sensitive")
                              ("smart" "--smart-case")
                              (_ "--ignore-case")))
             (expected
              (append my/search-rg-base-arguments
                      '("--hidden" "--no-ignore" "--follow")
                      (list case-argument)
                      (if (string-equal (nth 2 case) "fixed")
                          '("--fixed-strings")
                        nil)
                      '("--glob" "*.el" "--type" "elisp" "--context" "2")
                      (if (string-match-p "\n" query) '("--multiline") nil)
                      (list "-e" query "--" root))))
        (unwind-protect
            (cl-letf (((symbol-function 'make-process)
                       (lambda (&rest arguments)
                         (setq command (plist-get arguments :command))
                         'rg-process))
                      ((symbol-function 'process-live-p)
                       (lambda (process) (and process t)))
                      ((symbol-function 'delete-process)
                       (lambda (&rest ignored) (ignore ignored))))
              (my/search-rg-start-generation session query)
              (should (equal command expected))
              (should (= (cl-count "-e" command :test #'string-equal) 1))
              (should (= (cl-count query command :test #'string-equal) 1))
              (let ((pattern-index (cl-position "-e" command :test #'string-equal))
                    (separator-index (cl-position "--" command :test #'string-equal)))
                (should (string-equal (nth (1+ pattern-index) command) query))
                (should (string-equal (nth (1+ separator-index) command) root))
                (should (< pattern-index separator-index)))
              (should
               (equal
                (my/search-consult-ripgrep-arguments args)
                (append
                 '("rg" "--null" "--line-buffered" "--color=never"
                   "--max-columns=1000" "--path-separator" "/" "--no-heading"
                   "--with-filename" "--line-number" "--search-zip"
                   "--hidden" "--no-ignore" "--follow")
                 (list case-argument)
                 (if (string-equal (nth 2 case) "fixed")
                     '("--fixed-strings")
                   nil)
                 '("--glob" (list "*.el") "--type" (list "elisp")
                   "--context" (list "2"))))))
          (cl-letf (((symbol-function 'process-live-p)
                     (lambda (process) (and process t)))
                    ((symbol-function 'delete-process)
                     (lambda (&rest ignored) (ignore ignored))))
            (my/search-rg-close-session session)))))))

(ert-deftest my/search-rg-streams-current-json-and-cleans-replaced-processes ()
  (let* ((session (make-my/search-rg-session
                   :root "/tmp/my-search-root/" :args my/search-ripgrep-default-args
                   :generation 0 :tail "" :active t))
         (my/search-active-rg-session session)
         (record
          "{\"type\":\"match\",\"data\":{\"path\":{\"text\":\"src/file.el\"},\"lines\":{\"text\":\"alpha \\t\\n\"},\"line_number\":7,\"submatches\":[{\"start\":2}]}}\n")
         created
         deleted
         messages
         state
         status)
    (unwind-protect
        (cl-letf (((symbol-function 'make-process)
                   (lambda (&rest arguments)
                     (let ((process (intern (format "rg-%d" (1+ (length created))))))
                       (push (cons process arguments) created)
                       process)))
                  ((symbol-function 'process-live-p)
                   (lambda (process) (and process t)))
                  ((symbol-function 'delete-process)
                   (lambda (process) (push process deleted)))
                  ((symbol-function 'my/search-rg-publish)
                   (lambda (&rest ignored) (ignore ignored)))
                  ((symbol-function 'process-status)
                   (lambda (&rest ignored) (ignore ignored) state))
                  ((symbol-function 'process-exit-status)
                   (lambda (&rest ignored) (ignore ignored) status))
                  ((symbol-function 'message)
                   (lambda (format-string &rest arguments)
                     (push (apply #'format format-string arguments) messages))))
          (my/search-rg-start-generation session "first")
          (let ((first-process (my/search-rg-session-process session))
                (first-buffer (my/search-rg-session-buffer session)))
            (my/search-rg-start-generation session "second")
            (let* ((generation (my/search-rg-session-generation session))
                   (process (my/search-rg-session-process session))
                   (filter (plist-get (cdr (assq process created)) :filter)))
              (should (member first-process deleted))
              (should-not (buffer-live-p first-buffer))
              (funcall (plist-get (cdr (assq first-process created)) :filter)
                       first-process record)
              (should-not (my/search-rg-session-candidates session))
              (funcall filter process (substring record 0 31))
              (should-not (my/search-rg-session-candidates session))
              (funcall filter process (substring record 31))
              (let ((candidate (car (my/search-rg-session-candidates session))))
                (should (my/search-rg-candidate-p candidate))
                (should (equal (my/search-rg-candidate-file candidate)
                               "/tmp/my-search-root/src/file.el"))
                (should (= (my/search-rg-candidate-line candidate) 7))
                (should (= (my/search-rg-candidate-column candidate) 3))
                (should (string-equal (my/search-rg-candidate-text candidate)
                                      "alpha \t")))
              (setq state 'exit status 1)
              (my/search-rg-sentinel session generation process)
              (should-not messages)
              (setq state 'signal status 1)
              (my/search-rg-sentinel session generation process)
              (should (equal messages
                             '("ripgrep search failed with status 1"))))))
      (cl-letf (((symbol-function 'process-live-p)
                 (lambda (process) (and process t)))
                ((symbol-function 'delete-process)
                 (lambda (process) (push process deleted))))
        (let ((buffer (my/search-rg-session-buffer session))
              (process (my/search-rg-session-process session)))
          (my/search-rg-close-session session)
          (should (member process deleted))
          (should-not (buffer-live-p buffer))
          (should-not (my/search-rg-session-process session))
          (should-not (my/search-rg-session-buffer session))
          (should-not my/search-active-rg-session))))))

(ert-deftest my/search-ivy-rg-unwind-restores-cancel-and-keeps-results ()
  (dolist (scenario '(cancel accept export))
    (let* ((root (file-name-as-directory (make-temp-file "my-search-ivy-rg-" t)))
           (target (expand-file-name "target.el" root))
           (source (generate-new-buffer " *my-search-ivy-source*"))
           (minibuffer (generate-new-buffer " *my-search-ivy-minibuffer*"))
           process-arguments
           ivy-arguments
           published
           export-buffer
           deleted)
      (unwind-protect
          (progn
            (with-temp-file target
              (insert "first\nsecond\nthird\n"))
            (save-window-excursion
              (switch-to-buffer source)
              (dotimes (line 80)
                (insert (format "line %d\n" line)))
              (goto-char (point-min))
              (forward-line 50)
              (let ((origin-window (selected-window))
                    (origin-point (point))
                    (origin-start (line-beginning-position))
                    (minibuffer-window (split-window nil nil 'below)))
                (set-window-start origin-window origin-start)
                (set-window-buffer minibuffer-window minibuffer)
                (cl-letf (((symbol-function 'executable-find)
                           (lambda (&rest ignored) (ignore ignored) "rg"))
                          ((symbol-function 'require)
                           (let ((original-require (symbol-function 'require)))
                             (lambda (feature &optional filename noerror)
                               (if (eq feature 'ivy)
                                   'ivy
                                 (funcall original-require feature filename noerror)))))
                          ((symbol-function 'make-process)
                           (lambda (&rest arguments)
                             (setq process-arguments arguments)
                             'rg-process))
                          ((symbol-function 'process-live-p)
                           (lambda (process) (and process t)))
                          ((symbol-function 'delete-process)
                           (lambda (process) (push process deleted)))
                          ((symbol-function 'active-minibuffer-window)
                           (lambda () minibuffer-window))
                          ((symbol-function 'ivy-update-candidates)
                           (lambda (candidates)
                             (setq published candidates)))
                          ((symbol-function 'ivy-exit-with-action)
                           (lambda (action &rest ignored)
                             (ignore ignored)
                             (setq export-buffer (funcall action nil))))
                          ((symbol-function 'ivy-read)
                           (lambda (_prompt collection &rest arguments)
                             (setq ivy-arguments arguments)
                             (funcall collection "needle")
                             (funcall (plist-get process-arguments :filter)
                                      'rg-process
                                      "{\"type\":\"match\",\"data\":{\"path\":{\"text\":\"target.el\"},\"lines\":{\"text\":\"second\\n\"},\"line_number\":2,\"submatches\":[{\"start\":0}]}}\n")
                             (pcase scenario
                               ('cancel
                                (signal 'quit nil))
                               ('export
                                (my/search-rg-export))
                               (_
                                (funcall
                                 (plist-get arguments :action)
                                 (my/search-rg-candidate-display
                                  (make-my/search-rg-candidate
                                   :file target :line 2 :column 1 :text "second")
                                  root)))))))
                  (if (eq scenario 'cancel)
                      (should (eq (condition-case nil
                                      (my/search-ivy-ripgrep
                                       root nil my/search-ripgrep-default-args)
                                    (quit 'quit))
                                  'quit))
                    (my/search-ivy-ripgrep root nil my/search-ripgrep-default-args))
                  (let ((matcher (plist-get ivy-arguments :matcher)))
                    (should (functionp matcher))
                    (should (equal (funcall matcher "needle" '("candidate"))
                                   '("candidate"))))
                  (should (eq (plist-get ivy-arguments :update-fn) 'auto))
                  (should published)
                  (pcase scenario
                    ('cancel
                     (should (eq (window-buffer origin-window) source))
                     (should (= (point) origin-point))
                     (should (= (window-start origin-window) origin-start)))
                    ('accept
                     (should (eq (current-buffer) (get-file-buffer target))))
                    ('export
                     (should (eq (current-buffer) export-buffer))
                     (with-current-buffer export-buffer
                       (should (derived-mode-p 'grep-mode)))))
                  (should (equal deleted '(rg-process))))))
        (let ((target-buffer (get-file-buffer target)))
          (when (buffer-live-p target-buffer)
            (kill-buffer target-buffer)))
        (when (buffer-live-p export-buffer)
          (kill-buffer export-buffer))
        (when (buffer-live-p source)
          (kill-buffer source))
        (when (buffer-live-p minibuffer)
          (kill-buffer minibuffer))
        (delete-directory root t))))))

(ert-deftest my/search-rg-export-snapshots-candidates-without-a-process ()
  (let* ((root (file-name-as-directory (make-temp-file "my-search-export-" t)))
         (file (expand-file-name "source.el" root))
         (session (make-my/search-rg-session
                   :root root :active t
                   :candidates
                   (list (make-my/search-rg-candidate
                          :file file :line 3 :column 2 :text "result \t"))))
         (my/search-active-rg-session session)
         export-buffer)
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "one\ntwo\nresult\n"))
          (save-window-excursion
            (cl-letf (((symbol-function 'ivy-exit-with-action)
                       (lambda (action &rest ignored)
                         (ignore ignored)
                         (funcall action nil)))
                      ((symbol-function 'make-process)
                       (lambda (&rest ignored)
                         (ignore ignored)
                         (error "Export must not start a process")))
                      ((symbol-function 'my/search-rg-collection)
                       (lambda (&rest ignored)
                         (ignore ignored)
                         (error "Export must not start a fresh collection"))))
              (dolist (key '("C-q" "C-c C-o"))
                (let ((command (lookup-key my/search-rg-map (kbd key))))
                  (should (eq command #'my/search-rg-export))
                  (funcall command)
                  (setq export-buffer
                        (my/search-rg-session-export-buffer session))
                  (should (buffer-live-p export-buffer))
                  (with-current-buffer export-buffer
                    (should (derived-mode-p 'grep-mode))
                    (should (string-match-p (regexp-quote file) (buffer-string)))
                    (should (string-match-p (regexp-quote "result \t\n")
                                            (buffer-string))))
                  (pop-to-buffer export-buffer)
                  (goto-char (point-min))
                  (next-error 1 t)
                  (let ((file-buffer (get-file-buffer file)))
                    (should (buffer-live-p file-buffer))
                    (with-current-buffer file-buffer
                      (should (= (line-number-at-pos) 3))
                      (should (= (1+ (current-column)) 1)))))))))
      (when (buffer-live-p export-buffer)
        (kill-buffer export-buffer))
      (let ((file-buffer (get-file-buffer file)))
        (when (buffer-live-p file-buffer)
          (kill-buffer file-buffer)))
      (delete-directory root t))))

(ert-deftest my/search-transients-reload-without-duplicate-suffixes ()
  (let ((module (expand-file-name
                 "my-search.el"
                 my/search-test-directory)))
    (dolist (prefix '(my/search-line-menu
                      my/search-lines-menu
                      my/search-buffer-menu
                      my/search-ripgrep-menu))
      (load module nil nil nil t)
      (let ((count (length (transient-suffixes prefix))))
        (load module nil nil nil t)
        (should (= count (length (transient-suffixes prefix))))))))

(provide 'my-search-test)

;;; my-search-test.el ends here
