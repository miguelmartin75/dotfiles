;;; my-file-picker-test.el --- Tests for my-file-picker -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'my-completion-stack)
(require 'my-file-picker)

(declare-function ivy-completing-read "ivy")

(defvar consult-fd-args)
(defvar consult-find-args)
(defvar tramp-methods)
(defvar ivy-mode)

(ert-deftest my/file-picker-controller-transfers-results-between-frontends ()
  (let ((source (generate-new-buffer " *file-picker-source*"))
        (target (generate-new-buffer " *file-picker-target*"))
        (root "/tmp/file-picker-root/")
        recursive-call
        jumps)
    (unwind-protect
        (progn
          (with-current-buffer source
            (insert "source")
            (goto-char 3)
            (cl-letf (((symbol-function 'my/file-picker-hierarchical-session)
                       (lambda (&rest ignored)
                         (ignore ignored)
                         '(toggle-recursive "nested/file name.txt")))
                      ((symbol-function 'my/file-picker-recursive-session)
                       (lambda (next-root initial literal-initial)
                         (setq recursive-call
                               (list next-root initial literal-initial))
                         '(selected "/tmp/file-picker-root/nested/file name.txt")))
                      ((symbol-function 'find-file)
                       (lambda (&rest ignored)
                         (ignore ignored)
                         target))
                      ((symbol-function 'evil-set-jump)
                       (lambda (marker)
                         (push (list (marker-buffer marker)
                                     (marker-position marker))
                               jumps))))
              (should (eq (my/file-picker-run 'hierarchical root nil) target))))
          (should (equal recursive-call
                         (list "/tmp/file-picker-root/nested/"
                               "file name.txt" t)))
          (should (equal jumps (list (list source 3)))))
      (kill-buffer source)
      (kill-buffer target))))

(ert-deftest my/file-picker-controller-recovers-recursive-query-for-hierarchy ()
  (let (hierarchical-call)
    (cl-letf (((symbol-function 'my/file-picker-recursive-session)
               (lambda (&rest ignored)
                 (ignore ignored)
                 '(toggle-hierarchical "#file\\.el")))
              ((symbol-function 'my/file-picker-literal-query)
               (lambda (query)
                 (should (string-equal query "#file\\.el"))
                 "file.el"))
              ((symbol-function 'my/file-picker-hierarchical-session)
               (lambda (root initial)
                 (setq hierarchical-call (list root initial))
                 '(cancel))))
      (let ((my/completion-stack 'native-consult))
        (should-not (my/file-picker-run 'recursive "/tmp/file-picker-root/" nil)))
      (should (equal hierarchical-call
                     '("/tmp/file-picker-root/" "file.el"))))))

(ert-deftest my/file-picker-toggle-records-results-and-rejects-incomplete-tramp ()
  (with-temp-buffer
    (let ((my/file-picker-result nil)
          (tramp-methods '(("sshx"))))
      (setq-local my/file-picker-kind 'hierarchical
                  my/file-picker-root "/tmp/file-picker-root/")
      (cl-letf (((symbol-function 'minibufferp) (lambda (&rest ignored)
                                                   (ignore ignored) t))
                ((symbol-function 'minibuffer-contents-no-properties)
                 (lambda () "nested/file.el"))
                ((symbol-function 'abort-recursive-edit)
                 (lambda () (signal 'quit nil))))
        (should (eq (condition-case nil
                        (my/file-picker-toggle)
                      (quit 'quit))
                    'quit))
        (should (equal my/file-picker-result
                       '(toggle-recursive "nested/file.el")))))
    (let ((tramp-methods '(("sshx"))))
      (setq-local my/file-picker-kind 'hierarchical
                  my/file-picker-root "/tmp/file-picker-root/")
      (cl-letf (((symbol-function 'minibufferp) (lambda (&rest ignored)
                                                   (ignore ignored) t))
                ((symbol-function 'minibuffer-contents-no-properties)
                 (lambda () "/sshx:"))
                ((symbol-function 'file-remote-p)
                 (lambda (&rest ignored) (ignore ignored) nil)))
        (should-error (my/file-picker-toggle) :type 'user-error)))))

(ert-deftest my/file-picker-project-session-uses-public-relative-candidates ()
  (let ((completion-ignore-case t)
        (root "/tmp/file-picker-project/")
        collection)
    (cl-letf (((symbol-function 'project-files)
               (lambda (&rest ignored)
                 (ignore ignored)
                 '("src/one.el" "/tmp/file-picker-project/README.md")))
              ((symbol-function 'completing-read)
               (lambda (prompt candidates &rest ignored)
                 (ignore prompt ignored)
                 (setq collection candidates)
                 "SRC/ONE.EL")))
      (should (equal
               (my/file-picker-project-session 'project root nil)
               '(selected "/tmp/file-picker-project/src/one.el")))
      (should (equal (mapcar #'car collection)
                     '("src/one.el" "README.md"))))
    (cl-letf (((symbol-function 'project-files)
               (lambda (&rest ignored)
                 (ignore ignored)
                 '("src/one.el" "src/ONE.EL")))
              ((symbol-function 'completing-read)
               (lambda (&rest ignored)
                 (ignore ignored)
                 "src/ONE.EL")))
      (should
       (equal
        (my/file-picker-project-session 'project root nil)
        '(selected "/tmp/file-picker-project/src/ONE.EL"))))
    (cl-letf (((symbol-function 'project-files)
               (lambda (&rest ignored) (ignore ignored) nil)))
      (should-error (my/file-picker-project-session 'project root nil)
                    :type 'user-error))))

(ert-deftest my/file-picker-recursive-routing-keeps-remote-consult-native ()
  (let (calls observed)
    (cl-letf (((symbol-function 'transient-args)
               (lambda (&rest ignored)
                 (ignore ignored)
                 my/file-picker-fzf-default-args))
              ((symbol-function 'file-remote-p)
               (lambda (root &rest ignored)
                 (ignore ignored)
                 (and (string-prefix-p "/sshx:" root) "sshx")))
              ((symbol-function 'my/file-picker-consult-recursive-session)
               (lambda (&rest arguments)
                 (push (cons 'consult arguments) calls)
                 '(cancel)))
              ((symbol-function 'my/file-picker-ivy-fzf-session)
               (lambda (&rest arguments)
                 (push (cons 'ivy arguments) calls)
                 '(cancel))))
      (let ((my/completion-stack 'native-consult))
        (my/file-picker-recursive-session "/tmp/local/" "native"))
      (let ((my/completion-stack 'ivy-counsel))
        (my/file-picker-recursive-session "/tmp/local/" "ivy")
        (cl-letf (((symbol-function 'my/call-with-native-completion)
                   (lambda (function &rest arguments)
                     (let ((ivy-mode nil)
                           (completing-read-function #'completing-read-default))
                       (setq observed (list ivy-mode completing-read-function))
                       (apply function arguments)))))
          (my/file-picker-recursive-session "/sshx:user@host:/repo/" "remote")))
      (should (equal observed '(nil completing-read-default)))
      (should (equal (mapcar #'car (nreverse calls))
                     '(consult ivy consult))))))

(ert-deftest my/file-picker-native-adapter-restores-ivy-after-remote-call ()
  (let ((ivy-mode t)
        (completing-read-function #'ivy-completing-read)
        observed)
    (should
     (eq (my/call-with-native-completion
          (lambda ()
            (setq observed (list ivy-mode completing-read-function))
            'done))
         'done))
    (should (equal observed '(nil completing-read-default)))
    (should ivy-mode)
    (should (eq completing-read-function #'ivy-completing-read))
    (should
     (eq (condition-case nil
             (my/call-with-native-completion
              (lambda () (signal 'quit nil)))
           (quit 'quit))
         'quit))
    (should ivy-mode)
    (should (eq completing-read-function #'ivy-completing-read))))

(ert-deftest my/file-picker-remote-consult-prefers-fd-and-validates-find-options ()
  (let ((args '("--hidden" "--no-ignore" "--follow"
                "--case=insensitive"))
        calls)
    (cl-letf (((symbol-function 'my/file-picker-prompt-result)
               (lambda (kind root syntax function)
                 (push (list kind root syntax) calls)
                 (list 'selected (funcall function))))
              ((symbol-function 'consult-fd)
               (lambda (&rest ignored)
                 (ignore ignored)
                 (push (list 'fd consult-fd-args) calls)
                 "/sshx:user@host:/repo/fd.el"))
              ((symbol-function 'consult-find)
               (lambda (&rest ignored)
                 (ignore ignored)
                 (push (list 'find consult-find-args) calls)
                 "/sshx:user@host:/repo/find.el")))
      (cl-letf (((symbol-function 'executable-find)
                 (lambda (&rest ignored) (ignore ignored) "/remote/fd")))
        (should
         (equal (my/file-picker-consult-recursive-session
                 "/sshx:user@host:/repo/" nil args t)
                '(selected "/sshx:user@host:/repo/fd.el")))
        (should (member "--ignore-case" (cadr (assq 'fd calls)))))
      (setq calls nil)
      (cl-letf (((symbol-function 'executable-find)
                 (lambda (&rest ignored) (ignore ignored) nil)))
        (should
         (equal (my/file-picker-consult-recursive-session
                 "/sshx:user@host:/repo/" nil args t)
                '(selected "/sshx:user@host:/repo/find.el")))
        (should (equal (cl-subseq (cadr (assq 'find calls)) 0 3)
                       '("find" "-L" ".")))
        (should-error
         (my/file-picker-consult-recursive-session
          "/sshx:user@host:/repo/" nil '("--case=smart") t)
         :type 'user-error)))))

(ert-deftest my/file-picker-translates-stack-neutral-argv-with-literal-query ()
  (dolist (case '(("insensitive" "--ignore-case" "--ignore-case")
                  ("smart" nil "--smart-case")
                  ("sensitive" "--case-sensitive" "+i")))
    (let* ((args (list "--root=project" "--hidden" "--no-ignore"
                       (concat "--case=" (car case))))
           (fd (my/file-picker-fd-arguments args))
           (query "$(touch bad); --filter='quoted' [a-z]")
           (fzf (my/file-picker-fzf-arguments query args)))
      (should (member "--hidden" fd))
      (should (member "--no-ignore" fd))
      (should-not (member "--follow" fd))
      (if (cadr case)
          (should (member (cadr case) fd))
        (should-not (member "--ignore-case" fd)))
      (should (member (caddr case) fzf))
      (should (member (concat "--filter=" query) fzf))
      (should-not (member query fzf)))))

(ert-deftest my/file-picker-fzf-generation-owns-processes-and-rejects-stale-output ()
  (let* ((session (make-my/file-picker-ivy-fzf-session
                   :root "/tmp/file-picker-root/" :generation 0
                   :tail "" :active t))
         (my/file-picker-active-ivy-fzf-session session)
         created
         deleted
         forwarded
         eof
         buffers)
    (unwind-protect
        (cl-letf (((symbol-function 'make-process)
                   (lambda (&rest arguments)
                     (let ((process
                            (intern
                             (format "process-%d" (1+ (length created))))))
                       (push (cons process arguments) created)
                       process)))
                  ((symbol-function 'process-live-p)
                   (lambda (process) (and process t)))
                  ((symbol-function 'delete-process)
                   (lambda (process) (push process deleted)))
                  ((symbol-function 'process-send-string)
                   (lambda (process output)
                     (push (list process output) forwarded)))
                  ((symbol-function 'process-send-eof)
                   (lambda (process) (push process eof)))
                  ((symbol-function 'process-status)
                   (lambda (&rest ignored) (ignore ignored) 'exit))
                  ((symbol-function 'process-exit-status)
                   (lambda (&rest ignored) (ignore ignored) 0)))
          (my/file-picker-start-fzf-generation
           session my/file-picker-fzf-default-args "first")
          (setq buffers
                (list (my/file-picker-ivy-fzf-session-fd-buffer session)
                      (my/file-picker-ivy-fzf-session-fzf-buffer session)))
          (let ((first-fd
                 (my/file-picker-ivy-fzf-session-fd-process session))
                (first-fzf
                 (my/file-picker-ivy-fzf-session-fzf-process session)))
            (my/file-picker-start-fzf-generation
             session my/file-picker-fzf-default-args "second")
            (setq buffers
                  (append
                   (list (my/file-picker-ivy-fzf-session-fd-buffer session)
                         (my/file-picker-ivy-fzf-session-fzf-buffer session))
                   buffers))
            (should
             (equal
              (sort (copy-sequence deleted)
                    (lambda (left right)
                      (string< (symbol-name left) (symbol-name right))))
              (sort (list first-fd first-fzf)
                    (lambda (left right)
                      (string< (symbol-name left) (symbol-name right)))))))
          (let ((generation
                 (my/file-picker-ivy-fzf-session-generation session))
                (fd (my/file-picker-ivy-fzf-session-fd-process session))
                (fzf (my/file-picker-ivy-fzf-session-fzf-process session)))
            (my/file-picker-fd-filter session generation fd "one\0")
            (should (equal forwarded (list (list fzf "one\0"))))
            (my/file-picker-fd-sentinel session generation fd)
            (should (equal eof (list fzf)))
            (my/file-picker-fzf-filter session generation fzf "one\0two")
            (should
             (equal (my/file-picker-ivy-fzf-session-candidates session)
                    '("one")))
            (should
             (string-equal (my/file-picker-ivy-fzf-session-tail session) "two"))
            (my/file-picker-fzf-filter session generation fzf "\0three\0")
            (should
             (equal (my/file-picker-ivy-fzf-session-candidates session)
                    '("one" "two" "three")))
            (my/file-picker-fzf-filter
             session (1- generation) fzf "stale\0")
            (should-not
             (member "stale"
                     (my/file-picker-ivy-fzf-session-candidates session))))
          (should (= (length created) 4))
          (dolist (entry created)
            (should (listp (plist-get (cdr entry) :command)))
            (should
             (eq (plist-get (cdr entry) :coding)
                 (or file-name-coding-system
                     default-file-name-coding-system
                     'utf-8-unix))))
          (my/file-picker-close-fzf-session session)
          (should-not (my/file-picker-ivy-fzf-session-fd-process session))
          (should-not (my/file-picker-ivy-fzf-session-fzf-process session))
          (dolist (buffer buffers)
            (should-not (buffer-live-p buffer))))
      (dolist (buffer buffers)
        (when (buffer-live-p buffer)
          (kill-buffer buffer))))))

(ert-deftest my/file-picker-fzf-processes-decode-utf-8-nul-candidates ()
  (unless (and (executable-find "fd") (executable-find "fzf"))
    (ert-skip "fd and fzf are required"))
  (let* ((root (file-name-as-directory
                (make-temp-file "file-picker-utf-8-" t)))
         (file (expand-file-name "caf\u00e9.txt" root))
         (session (make-my/file-picker-ivy-fzf-session
                   :root root :generation 0 :tail "" :active t))
         (my/file-picker-active-ivy-fzf-session session))
    (unwind-protect
        (progn
          (with-temp-file file)
          (my/file-picker-start-fzf-generation
           session my/file-picker-fzf-default-args "")
          (while (or (process-live-p
                      (my/file-picker-ivy-fzf-session-fd-process session))
                     (process-live-p
                      (my/file-picker-ivy-fzf-session-fzf-process session)))
            (accept-process-output nil 0.1))
          (accept-process-output nil 0.1)
          (should
           (member
            "./caf\u00e9.txt"
            (mapcar #'ucs-normalize-NFC-string
                    (my/file-picker-ivy-fzf-session-candidates session)))))
      (my/file-picker-close-fzf-session session)
      (delete-directory root t))))

(ert-deftest my/file-picker-fzf-sentinel-treats-no-match-as-normal ()
  (let* ((session (make-my/file-picker-ivy-fzf-session
                   :generation 1 :fzf-process 'fzf :active t))
         (my/file-picker-active-ivy-fzf-session session)
         (state 'exit)
         (status 1)
         messages)
    (cl-letf (((symbol-function 'process-status)
               (lambda (&rest ignored) (ignore ignored) state))
              ((symbol-function 'process-exit-status)
               (lambda (&rest ignored) (ignore ignored) status))
              ((symbol-function 'message)
               (lambda (format-string &rest arguments)
                 (push (apply #'format format-string arguments) messages))))
      (my/file-picker-fzf-sentinel session 1 'fzf)
      (should-not messages)
      (setq status 2)
      (my/file-picker-fzf-sentinel session 1 'fzf)
      (should
       (equal messages '("fzf file discovery failed with status 2")))
      (setq state 'signal
            status 1)
      (my/file-picker-fzf-sentinel session 1 'fzf)
      (should
       (equal messages
              '("fzf file discovery failed with status 1"
                "fzf file discovery failed with status 2"))))))

(ert-deftest my/file-picker-fzf-export-builds-dired-snapshot-without-rerun ()
  (let* ((root (file-name-as-directory (make-temp-file "my-file-picker-export-" t)))
         (files (list (expand-file-name "src/one.el" root)
                      (expand-file-name "README.md" root)))
         (session (make-my/file-picker-ivy-fzf-session
                   :root root :active t
                   :candidates '("src/one.el" "README.md")))
         (my/file-picker-active-ivy-fzf-session session)
         dired-buffer)
    (unwind-protect
        (progn
          (make-directory (file-name-directory (car files)))
          (dolist (file files)
            (with-temp-file file
              (insert "exported file\n")))
          (cl-letf (((symbol-function 'ivy-exit-with-action)
                     (lambda (action &rest ignored)
                       (ignore ignored)
                       (funcall action nil)))
                    ((symbol-function 'make-process)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       (error "Export must not start another process")))
                    ((symbol-function 'my/file-picker-fzf-collection)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       (error "Export must not start a fresh collection"))))
            (dolist (key '("C-q" "C-c C-o"))
              (let ((command (lookup-key my/file-picker-ivy-fzf-map (kbd key))))
                (should (eq command #'my/file-picker-fzf-export))
                (funcall command)
                (setq dired-buffer
                      (my/file-picker-ivy-fzf-session-export-buffer session))
                (with-current-buffer dired-buffer
                  (should (derived-mode-p 'dired-mode))
                  (dolist (file files)
                    (should (dired-goto-file file))
                    (should (equal (dired-get-filename) file))))))))
      (when (buffer-live-p dired-buffer)
        (kill-buffer dired-buffer))
      (delete-directory root t))))

(ert-deftest my/file-picker-records-one-jump-only-for-successful-cross-buffer-visit ()
  (let ((source (generate-new-buffer " *file-picker-source*"))
        (target (generate-new-buffer " *file-picker-target*"))
        jumps
        visits)
    (unwind-protect
        (with-current-buffer source
          (insert "source")
          (goto-char 4)
          (cl-letf (((symbol-function 'my/file-picker-hierarchical-session)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       '(selected "/tmp/file-picker-target.el")))
                    ((symbol-function 'find-file)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       (setq visits (1+ (or visits 0)))
                       target))
                    ((symbol-function 'evil-set-jump)
                     (lambda (marker)
                       (push (list (marker-buffer marker)
                                   (marker-position marker))
                             jumps))))
            (should (eq (my/file-picker-run 'hierarchical "/tmp/" nil) target)))
          (cl-letf (((symbol-function 'my/file-picker-hierarchical-session)
                     (lambda (&rest ignored)
                       (ignore ignored)
                       '(cancel))))
            (should-not (my/file-picker-run 'hierarchical "/tmp/" nil)))
          (should (= visits 1))
          (should (equal jumps (list (list source 4)))))
      (kill-buffer source)
      (kill-buffer target))))

(provide 'my-file-picker-test)

;;; my-file-picker-test.el ends here
