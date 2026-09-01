;;; my-file-picker-test.el --- Tests for my-file-picker -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'my-file-picker)

(defvar consult-async-split-style)
(defvar consult-async-split-styles-alist)
(defvar consult-fd-args)
(defvar consult-find-args)

(ert-deftest my/file-picker-toggle-successfully-selects-once ()
  (let ((root (file-name-as-directory (make-temp-file "picker root " t))))
    (unwind-protect
        (dolist (case '((hierarchical "nested/file name.txt"
                                     "file name\\.txt")
                        (hierarchical ".hidden" "\\.hidden")
                        (hierarchical "+notes" "\\+notes")
                        (recursive "file name\\.txt" "file name.txt")))
          (let ((opened (list nil))
                captured-root
                captured-initial
                captured-split-style
                (aborts 0)
                (consult-async-split-style 'perl)
                (my/file-picker-transaction (list nil)))
            (cl-letf (((symbol-function 'my/file-picker-recursive-session)
                       (lambda (dir initial)
                         (setq captured-root dir
                               captured-initial initial
                               captured-split-style
                               consult-async-split-style)
                         (let ((file (expand-file-name "file name.txt" dir))
                               (buffer (generate-new-buffer
                                        " *my-file-picker-test*")))
                           (setcar opened (cons file (car opened)))
                           (with-current-buffer buffer
                             (setq buffer-file-name file))
                           buffer)))
                      ((symbol-function 'my/file-picker-hierarchical-session)
                       (lambda (dir initial)
                         (setq captured-root dir
                               captured-initial initial)
                         (expand-file-name initial dir)))
                      ((symbol-function 'find-file)
                       (lambda (file &rest _ignored)
                         (setcar opened (cons file (car opened)))
                         (let ((buffer (generate-new-buffer
                                        " *my-file-picker-test*")))
                           (with-current-buffer buffer
                             (setq buffer-file-name file))
                           buffer)))
                      ((symbol-function 'abort-recursive-edit)
                       (lambda ()
                         (setq aborts (1+ aborts))
                         (signal 'quit nil))))
              (with-current-buffer (window-buffer (minibuffer-window))
                (let ((inhibit-read-only t))
                  (erase-buffer)
                  (insert (cadr case))
                  (setq-local my/file-picker-kind (car case)
                              my/file-picker-root root)
                  (should
                   (eq (condition-case nil
                           (my/file-picker-toggle)
                         (quit 'quit))
                       'quit))))
              (should (= aborts 2))
              (should (= (length (car opened)) 1))
              (if (eq (car case) 'hierarchical)
                  (progn
                    (should (string-equal captured-root
                                          (if (string-prefix-p "nested/"
                                                               (cadr case))
                                              (expand-file-name "nested/" root)
                                            root)))
                    (should (string-equal captured-initial (caddr case)))
                    (should-not captured-split-style))
                (should (string-suffix-p (caddr case)
                                         (car (car opened))))))))
      (delete-directory root t))))

(ert-deftest my/file-picker-hierarchical-read-file-name-initialization ()
  (let ((root "/tmp/picker-root/")
        (nested-root "/tmp/picker-root/nested/")
        calls
        composed-initial
        opened)
    (cl-letf (((symbol-function 'read-file-name)
               (lambda (prompt &optional directory default-filename mustmatch
                               initial predicate)
                 (push (list prompt directory default-filename mustmatch
                             initial predicate)
                       calls)
                 "/tmp/selected"))
              ((symbol-function 'find-file)
               (lambda (file &rest _ignored)
                 (setq opened file))))
      (my/file-picker-hierarchical-session nested-root "file name.txt")
      (let ((default-directory root))
        (my/find-file-sshx)))
    (should
     (equal (nreverse calls)
            `(("Find file: " ,nested-root nil nil "file name.txt" nil)
              ("Find file: " "/" nil nil "sshx:" nil))))
    (cl-letf (((symbol-function 'read-from-minibuffer)
               (lambda (_prompt &optional initial-contents &rest _ignored)
                 (setq composed-initial
                       (if (consp initial-contents)
                           (car initial-contents)
                         initial-contents))
                 composed-initial)))
      (my/file-picker-hierarchical-session root "/sshx:"))
    (should (string-equal composed-initial "/sshx:"))
    (should (string-equal opened "/tmp/selected"))))

(ert-deftest my/file-picker-project-toggle-transfers-input-literally ()
  (let ((root "/tmp/project-root/")
        captured-kind
        captured-root
        captured-reader
        captured-initial
        (parser-calls 0)
        (split-style-bound (boundp 'consult-async-split-style))
        (split-style-value (and (boundp 'consult-async-split-style)
                                consult-async-split-style)))
    (unwind-protect
        (progn
          (makunbound 'consult-async-split-style)
          (cl-letf (((symbol-function 'project-current)
                     (lambda (&optional _maybe-prompt _directory) 'project))
                    ((symbol-function 'project-root)
                     (lambda (_project) root))
                    ((symbol-function 'project-find-file)
                     (lambda (&optional _include-all)
                       (run-hooks 'minibuffer-setup-hook)
                       (setq captured-kind my/file-picker-kind
                             captured-root my/file-picker-root
                             captured-reader
                             project-read-file-name-function)))
                    ((symbol-function 'my/file-picker-literal-query)
                     (lambda (_query)
                       (setq parser-calls (1+ parser-calls))
                       (error "Consult parser must not run"))))
            (with-current-buffer (window-buffer (minibuffer-window))
              (my/find-file-project))
            (should (eq captured-kind 'project))
            (should (string-equal captured-root root))
            (should (eq captured-reader #'project--read-file-absolute))
            (dolist (query '(".hidden" "#notes" "file.*" "/async/filter"))
              (let ((my/file-picker-transaction (list nil)))
                (cl-letf (((symbol-function 'my/file-picker-hierarchical-session)
                           (lambda (dir initial)
                             (setq captured-root dir
                                   captured-initial initial)
                             (expand-file-name "selected" dir)))
                          ((symbol-function 'find-file)
                           (lambda (&rest _ignored) nil))
                          ((symbol-function 'abort-recursive-edit)
                           (lambda () (signal 'quit nil))))
                  (with-current-buffer (window-buffer (minibuffer-window))
                    (let ((inhibit-read-only t))
                      (erase-buffer)
                      (insert query)
                      (setq-local my/file-picker-kind 'project
                                  my/file-picker-root root)
                      (should
                       (eq (condition-case nil
                               (my/file-picker-toggle)
                             (quit 'quit))
                           'quit))))
                  (should (string-equal captured-root root))
                  (should (string-equal captured-initial query)))))
            (should (= parser-calls 0))))
      (if split-style-bound
          (set 'consult-async-split-style split-style-value)
        (makunbound 'consult-async-split-style)))))

(ert-deftest my/file-picker-project-prompt-keeps-project-relative-paths ()
  (let ((root (file-name-as-directory (make-temp-file "picker-project-" t)))
        prompt
        collection
        opened)
    (unwind-protect
        (cl-letf (((symbol-function 'project-current)
                   (lambda (&optional _maybe-prompt _directory) 'project))
                  ((symbol-function 'project-root)
                   (lambda (_project) root))
                  ((symbol-function 'project-files)
                   (lambda (_project &optional _dirs)
                     '("src/a.el" "src/b.el")))
                  ((symbol-function 'thing-at-point)
                   (lambda (&rest _ignored) nil))
                  ((symbol-function 'completing-read)
                   (lambda (read-prompt read-collection &rest _ignored)
                     (setq prompt read-prompt
                           collection read-collection)
                     "src/a.el"))
                  ((symbol-function 'find-file)
                   (lambda (file &rest _ignored)
                     (setq opened file))))
          (my/find-file-project)
          (should (string-equal prompt (format "Find file in %s: " root)))
          (should (equal (all-completions "" collection)
                         '("src/a.el" "src/b.el")))
          (should (string-equal opened (expand-file-name "src/a.el" root))))
      (delete-directory root t))))

(ert-deftest my/file-picker-nested-cancel-restores-outer-state ()
  (let ((root (file-name-as-directory (make-temp-file "picker-cancel-" t))))
    (unwind-protect
        (dolist (case '((hierarchical "folder/file.txt")
                        (recursive "file.* -- --extension el")))
          (let ((refreshed nil)
                (my/file-picker-transaction (list nil)))
            (cl-letf (((symbol-function 'my/file-picker-recursive-session)
                       (lambda (&rest _ignored) (signal 'quit nil)))
                      ((symbol-function 'my/file-picker-hierarchical-session)
                       (lambda (&rest _ignored) (signal 'quit nil)))
                      ((symbol-function 'my/file-picker-refresh)
                       (lambda (buffer)
                         (with-current-buffer buffer
                           (setq refreshed
                                 (list my/file-picker-kind
                                       my/file-picker-root
                                       (minibuffer-contents-no-properties)))))))
              (with-current-buffer (window-buffer (minibuffer-window))
                (let ((inhibit-read-only t))
                  (erase-buffer)
                  (insert (cadr case))
                  (setq-local my/file-picker-kind (car case)
                              my/file-picker-root root)
                  (my/file-picker-toggle)))
              (should (eq (car refreshed) (car case)))
              (should (string-equal (cadr refreshed) root))
              (should (string-suffix-p (cadr case) (caddr refreshed))))))
      (delete-directory root t))))

(ert-deftest my/file-picker-query-and-path-transfer ()
  (let ((consult-async-split-styles-alist
         '((none)
           (comma :separator 44)
           (semicolon :separator 59)
           (perl :initial 35))))
    (dolist (case '((perl "#plain name.txt" "plain name.txt")
                    (perl "#name\\.txt" "name.txt")
                    (perl "#dir/name.txt" "dir/name.txt")
                    (perl "#\\.hidden" ".hidden")
                    (perl "#\\+notes" "+notes")
                    (perl "#file.*" nil)
                    (perl "##literal" nil)
                    (perl "#/async/filter" "/async/filter")
                    (perl "#foo#bar" nil)
                    (perl "#query --" nil)
                    (perl "#query -- --extension el" nil)
                    (perl "#--hidden" "--hidden")
                    (comma "async,filter" nil)
                    (comma ",leading" ",leading")
                    (comma "foo#bar" "foo#bar")
                    (semicolon "async;filter" nil)
                    (semicolon ";leading" ";leading")
                    (nil "/async/filter" "/async/filter")
                    (nil "query --" nil)
                    (nil "query -- -g *.el" nil)
                    (nil "query --hidden" "query --hidden")
                    (nil "--hidden" "--hidden")
                    (nil "\\.hidden" ".hidden")
                    (nil "\\+notes" "+notes")))
      (let ((consult-async-split-style (car case)))
        (should (equal (my/file-picker-literal-query (cadr case))
                       (caddr case))))))
  (dolist (case '(("/sshx:user@host:/repo/src/file.el"
                   "/sshx:user@host:/repo/src/" "file.el")
                  ("/absolute/root/file.el" "/absolute/root/" "file.el")
                  ("~/source/file.el" "~/source/" "file.el")
                  ("folder with spaces/file.el" "folder with spaces/" "file.el")))
    (should (string-equal (file-name-directory (car case)) (cadr case)))
    (should (string-equal (file-name-nondirectory (car case)) (caddr case)))))

(ert-deftest my/file-picker-toggle-requires-complete-remote-host ()
  (let ((root "/tmp/picker-root/")
        recursive-calls
        (my/file-picker-transaction (list nil)))
    (cl-letf (((symbol-function 'my/file-picker-recursive-session)
               (lambda (dir initial)
                 (push (list dir initial) recursive-calls)
                 (let ((buffer (generate-new-buffer
                                " *my-file-picker-remote-test*")))
                   (with-current-buffer buffer
                     (setq buffer-file-name (concat dir "selected")))
                   buffer)))
              ((symbol-function 'abort-recursive-edit)
               (lambda () (signal 'quit nil))))
      (dolist (input '("/sshx:"
                       "/sshx:/"
                       "/sshx::"
                       "/sshx:host/path/file.el"
                       "/sshx:user@host/path/file.el"))
        (with-current-buffer (window-buffer (minibuffer-window))
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert input)
            (setq-local my/file-picker-kind 'hierarchical
                        my/file-picker-root root)
            (should-error (my/file-picker-toggle)
                          :type 'user-error))))
      (should-not recursive-calls)
      (dolist (case '(("/sshx:host:"
                       "/sshx:host:" "")
                      ("/sshx:user@host:/repo/file.el"
                       "/sshx:user@host:/repo/" "file\\.el")))
        (let ((my/file-picker-transaction (list nil)))
          (with-current-buffer (window-buffer (minibuffer-window))
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert (car case))
              (setq-local my/file-picker-kind 'hierarchical
                          my/file-picker-root root)
              (should
               (eq (condition-case nil
                       (my/file-picker-toggle)
                     (quit 'quit))
                   'quit))))
          (should (equal (pop recursive-calls) (cdr case))))))))

(ert-deftest my/file-picker-selects-recursive-backend-and-find-contract ()
  (dolist (case '(("/tmp/root/" nil consult-fd)
                  ("/sshx:user@host:/repo/" "/remote/fd" consult-fd)
                  ("/sshx:user@host:/repo/" nil consult-find)))
    (let (called executable-default executable-remote captured-args)
      (cl-letf (((symbol-function 'file-remote-p)
                 (lambda (file &optional _identification _connected)
                   (and (string-prefix-p "/sshx:" file) "/sshx:user@host:")))
                ((symbol-function 'executable-find)
                 (lambda (_command &optional remote)
                   (setq executable-default default-directory
                         executable-remote remote)
                   (cadr case)))
                ((symbol-function 'consult-fd)
                 (lambda (_root _initial)
                   (setq called 'consult-fd
                         captured-args consult-fd-args)
                   (current-buffer)))
                ((symbol-function 'consult-find)
                 (lambda (_root _initial)
                   (setq called 'consult-find
                         captured-args consult-find-args)
                   (current-buffer))))
        (my/file-picker-recursive-session (car case) nil)
        (should (eq called (caddr case)))
        (if (string-prefix-p "/sshx:" (car case))
            (progn
              (should executable-remote)
              (should (string-equal executable-default (car case))))
          (should-not executable-remote))
        (should (member "f" captured-args))
        (if (eq called 'consult-find)
            (progn
              (should (member "-prune" captured-args))
              (should-not (member "-L" captured-args)))
          (should (member "--hidden" captured-args))
          (should (member "--no-ignore" captured-args))))))
  (let* ((root (file-name-as-directory (make-temp-file "picker-find-" t)))
         (default-directory root)
         (visible (expand-file-name "visible.txt" root))
         (hidden (expand-file-name ".hidden" root))
         (git-dir (expand-file-name ".git" root))
         (target-dir (expand-file-name "target" root))
         (link-dir (expand-file-name "linked" root)))
    (unwind-protect
        (progn
          (write-region "" nil visible nil 'silent)
          (write-region "" nil hidden nil 'silent)
          (make-directory git-dir)
          (write-region "" nil (expand-file-name "ignored" git-dir) nil 'silent)
          (make-directory target-dir)
          (write-region "" nil (expand-file-name "through-link" target-dir)
                        nil 'silent)
          (make-symbolic-link target-dir link-dir)
          (let ((files (apply #'process-lines my/file-picker-remote-find-args)))
            (should (member "./visible.txt" files))
            (should (member "./.hidden" files))
            (should-not (member "./.git/ignored" files))
            (should-not (member "./linked/through-link" files))))
      (delete-directory root t))))

;;; my-file-picker-test.el ends here
