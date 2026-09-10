;;; my-completion-stack-test.el --- Tests for completion stack lifecycle -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'package)

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'my-completion-stack)
(require 'my-file-picker)
(require 'my-search)

(defconst my/completion-stack-test-directory
  (file-name-directory (expand-file-name (or load-file-name buffer-file-name)))
  "Directory containing the completion stack module and tests.")

(defvar ivy-mode nil)
(defvar ivy-do-completion-in-region nil)
(defvar ivy-minibuffer-map)

(defun my/completion-stack-test-native-reader (&rest arguments)
  "Provide a distinct native reader for lifecycle tests."
  (apply #'completing-read-default arguments))

(defun my/completion-stack-test-native-completion-in-region
    (start end collection &optional predicate)
  "Provide a distinct native completion function for lifecycle tests."
  (completion--in-region start end collection predicate))

(defun my/completion-stack-test-native-xrefs (&rest arguments)
  "Provide a distinct native Xref presenter for lifecycle tests."
  arguments)

(defun my/completion-stack-test-native-definitions (&rest arguments)
  "Provide a distinct native definition presenter for lifecycle tests."
  arguments)

(defun my/completion-stack-test-state ()
  "Return the completion state that stack transitions own."
  (list my/completion-stack
        my/completion-stack-saved
        ivy-mode
        completing-read-function
        completion-in-region-function
        xref-show-xrefs-function
        xref-show-definitions-function))

(defmacro my/completion-stack-test-with-isolated-state (&rest body)
  "Evaluate BODY with an isolated stack and a public Ivy-mode model."
  (declare (indent 0) (debug t))
  `(let ((my/completion-stack nil)
         (my/completion-stack-saved nil)
         (my/completion-stack-captured t)
         (my/completion-stack-native-reader
          #'my/completion-stack-test-native-reader)
         (my/completion-stack-native-completion-in-region-function
          #'my/completion-stack-test-native-completion-in-region)
         (my/completion-stack-native-xref-show-xrefs-function
          #'my/completion-stack-test-native-xrefs)
         (my/completion-stack-native-xref-show-definitions-function
          #'my/completion-stack-test-native-definitions)
         (completing-read-function #'my/completion-stack-test-native-reader)
         (completion-in-region-function
          #'my/completion-stack-test-native-completion-in-region)
         (xref-show-xrefs-function #'my/completion-stack-test-native-xrefs)
         (xref-show-definitions-function
          #'my/completion-stack-test-native-definitions)
         (ivy-mode nil)
         (ivy-do-completion-in-region t))
     (let ((original-require (symbol-function 'require)))
       (cl-letf (((symbol-function 'require)
                  (lambda (feature &optional filename noerror)
                    (if (eq feature 'ivy)
                        'ivy
                      (funcall original-require feature filename noerror))))
                 ((symbol-function 'ivy-mode)
                  (lambda (enabled)
                    (setq ivy-mode (> enabled 0)
                          completing-read-function
                          (if ivy-mode
                              #'ivy-completing-read
                            my/completion-stack-native-reader)))))
         ,@body))))

(ert-deftest my/completion-stack-round-trip-preserves-native-contract ()
  (my/completion-stack-test-with-isolated-state
    (my/set-completion-stack 'native-consult)
    (should (equal (my/completion-stack-test-state)
                   '(native-consult native-consult nil
                                    my/completion-stack-test-native-reader
                                    my/completion-stack-test-native-completion-in-region
                                    consult-xref consult-xref)))
    (my/set-completion-stack 'ivy-counsel)
    (should (equal (my/completion-stack-test-state)
                   '(ivy-counsel ivy-counsel t ivy-completing-read
                                 my/completion-stack-test-native-completion-in-region
                                 my/completion-stack-test-native-xrefs
                                 my/completion-stack-test-native-definitions)))
    (should-not ivy-do-completion-in-region)
    (my/set-completion-stack 'native-consult)
    (should (equal (my/completion-stack-test-state)
                   '(native-consult native-consult nil
                                    my/completion-stack-test-native-reader
                                    my/completion-stack-test-native-completion-in-region
                                    consult-xref consult-xref)))))

(ert-deftest my/completion-stack-noop-and-invalid-input-do-not-mutate-state ()
  (my/completion-stack-test-with-isolated-state
    (my/set-completion-stack 'native-consult)
    (let ((before (my/completion-stack-test-state)))
      (cl-letf (((symbol-function 'ivy-mode)
                 (lambda (&rest _arguments)
                   (error "A no-op must not activate a frontend"))))
        (my/set-completion-stack 'native-consult))
      (should (equal (my/completion-stack-test-state) before))
      (should-error (my/set-completion-stack 'unsupported-stack)
                    :type 'user-error)
      (should (equal (my/completion-stack-test-state) before)))))

(ert-deftest my/completion-stack-active-sessions-reject-without-mutation ()
  (my/completion-stack-test-with-isolated-state
    (my/set-completion-stack 'native-consult)
    (let ((before (my/completion-stack-test-state)))
      (cl-letf (((symbol-function 'active-minibuffer-window)
                 (lambda () (selected-window))))
        (should-error (my/set-completion-stack 'ivy-counsel) :type 'user-error))
      (should (equal (my/completion-stack-test-state) before)))
    (let ((buffer (generate-new-buffer " *completion stack CIRF*")))
      (unwind-protect
          (progn
            (with-current-buffer buffer
              (setq-local completion-in-region-mode t))
            (let ((before (my/completion-stack-test-state)))
              (should-error (my/set-completion-stack 'ivy-counsel)
                            :type 'user-error)
              (should (equal (my/completion-stack-test-state) before))))
        (kill-buffer buffer)))
    (let ((before (my/completion-stack-test-state)))
      (cl-letf (((symbol-function 'transient-active-prefix)
                 (lambda () 'my/completion-stack-menu)))
        (should-error (my/set-completion-stack 'ivy-counsel) :type 'user-error))
      (should (equal (my/completion-stack-test-state) before)))))

(ert-deftest my/completion-stack-failure-rolls-back-and-keeps-original-error ()
  (my/completion-stack-test-with-isolated-state
    (my/set-completion-stack 'native-consult)
    (let ((before (my/completion-stack-test-state))
          condition)
      (cl-letf (((symbol-function 'ivy-mode)
                 (lambda (enabled)
                   (setq ivy-mode (> enabled 0)
                         completing-read-function
                         (if ivy-mode
                             #'ivy-completing-read
                           my/completion-stack-native-reader))
                   (when ivy-mode
                     (error "expected Ivy activation failure")))))
        (condition-case error-condition
            (my/set-completion-stack 'ivy-counsel)
          (error
           (setq condition error-condition))))
      (should (equal (error-message-string condition)
                     "expected Ivy activation failure"))
      (should (equal (my/completion-stack-test-state) before)))
    (let ((before (my/completion-stack-test-state))
          condition)
      (cl-letf (((symbol-function 'ivy-mode)
                 (lambda (enabled)
                   (setq ivy-mode (> enabled 0)
                         completing-read-function
                         (if ivy-mode
                             #'ivy-completing-read
                           my/completion-stack-native-reader))
                   (when ivy-mode
                     (signal 'quit nil)))))
        (condition-case quit-condition
            (my/set-completion-stack 'ivy-counsel)
          (quit
           (setq condition quit-condition))))
      (should (equal condition '(quit)))
      (should (equal (my/completion-stack-test-state) before)))))

(ert-deftest my/completion-stack-transitions-start-no-process-or-provisioning ()
  (my/completion-stack-test-with-isolated-state
    (let (activity advices)
      (unwind-protect
          (progn
            (dolist (function '(executable-find
                                process-file
                                file-remote-p
                                make-process
                                start-process
                                package-refresh-contents
                                package-install
                                package-install-file
                                package-vc-install))
              (let ((advice
                     (lambda (&rest arguments)
                       (ignore arguments)
                       (push function activity))))
                (advice-add function :before advice)
                (push (cons function advice) advices)))
            (my/select-native-completion-stack)
            (my/select-ivy-completion-stack)
            (my/toggle-completion-stack)
            (my/toggle-completion-stack)
            (my/select-native-completion-stack)
            (should-not activity))
        (dolist (entry advices)
          (advice-remove (car entry) (cdr entry)))))))

(ert-deftest my/completion-stack-transitions-preserve-persistent-results ()
  (my/completion-stack-test-with-isolated-state
    (let* ((root (file-name-as-directory
                  (make-temp-file "my-completion-stack-results-" t)))
           (file (expand-file-name "result.el" root))
           (file-session
            (make-my/file-picker-ivy-fzf-session
             :root root :active t :candidates '("result.el")))
           (search-session
            (make-my/search-rg-session
             :root root :active t
             :candidates
             (list (make-my/search-rg-candidate
                    :file file :line 2 :column 1 :text "result"))))
           (my/file-picker-active-ivy-fzf-session file-session)
           (my/search-active-rg-session search-session)
           dired-buffer
           grep-buffer)
      (unwind-protect
          (progn
            (with-temp-file file
              (insert "first\nresult\n"))
            (save-window-excursion
              (cl-letf (((symbol-function 'ivy-exit-with-action)
                         (lambda (action &rest arguments)
                           (ignore arguments)
                           (funcall action nil))))
                (my/file-picker-fzf-export)
                (my/search-rg-export))
              (setq dired-buffer
                    (my/file-picker-ivy-fzf-session-export-buffer file-session)
                    grep-buffer
                    (my/search-rg-session-export-buffer search-session))
              (should (buffer-live-p dired-buffer))
              (should (buffer-live-p grep-buffer))
              (my/set-completion-stack 'native-consult)
              (my/set-completion-stack 'ivy-counsel)
              (my/set-completion-stack 'native-consult)
              (with-current-buffer dired-buffer
                (should (derived-mode-p 'dired-mode))
                (should (dired-goto-file file))
                (should (equal (dired-get-filename) file)))
              (with-current-buffer grep-buffer
                (should (derived-mode-p 'grep-mode))
                (should (string-match-p (regexp-quote file) (buffer-string))))
              (pop-to-buffer grep-buffer)
              (goto-char (point-min))
              (next-error 1 t)
              (with-current-buffer (get-file-buffer file)
                (should (= (line-number-at-pos) 2)))))
        (when (buffer-live-p dired-buffer)
          (kill-buffer dired-buffer))
        (when (buffer-live-p grep-buffer)
          (kill-buffer grep-buffer))
        (let ((file-buffer (get-file-buffer file)))
          (when (buffer-live-p file-buffer)
            (kill-buffer file-buffer)))
        (delete-directory root t)))))

(ert-deftest my/completion-stack-menu-has-the-required-selecting-suffixes ()
  (dolist (spec '(("n" "Native and Consult" my/select-native-completion-stack)
                  ("i" "Ivy and Counsel" my/select-ivy-completion-stack)
                  ("t" "Toggle" my/toggle-completion-stack)))
    (let ((suffix (transient-get-suffix 'my/completion-stack-menu (car spec))))
      (should suffix)
      (should (equal (plist-get (cdr suffix) :description) (nth 1 spec)))
      (should (eq (plist-get (cdr suffix) :command) (nth 2 spec))))))

(ert-deftest my/completion-stack-capture-survives-module-reload-once ()
  (let ((module (expand-file-name
                 "my-completion-stack.el"
                 my/completion-stack-test-directory))
        (my/completion-stack-captured nil)
        (my/completion-stack-native-reader nil)
        (my/completion-stack-native-completion-in-region-function nil)
        (my/completion-stack-native-xref-show-xrefs-function nil)
        (my/completion-stack-native-xref-show-definitions-function nil)
        (completing-read-function #'my/completion-stack-test-native-reader)
        (completion-in-region-function
         #'my/completion-stack-test-native-completion-in-region)
        (xref-show-xrefs-function #'my/completion-stack-test-native-xrefs)
        (xref-show-definitions-function
         #'my/completion-stack-test-native-definitions))
    (load module nil nil nil t)
    (let ((captured (list my/completion-stack-native-reader
                          my/completion-stack-native-completion-in-region-function
                          my/completion-stack-native-xref-show-xrefs-function
                          my/completion-stack-native-xref-show-definitions-function))
          (suffix-count (length (transient-suffixes 'my/completion-stack-menu))))
      (setq completing-read-function #'ivy-completing-read
            completion-in-region-function #'ignore
            xref-show-xrefs-function #'ignore
            xref-show-definitions-function #'ignore)
      (load module nil nil nil t)
      (should (equal (list my/completion-stack-native-reader
                           my/completion-stack-native-completion-in-region-function
                           my/completion-stack-native-xref-show-xrefs-function
                           my/completion-stack-native-xref-show-definitions-function)
                     captured))
      (should (= (length (transient-suffixes 'my/completion-stack-menu))
                 suffix-count)))))

(ert-deftest my/completion-stack-native-capf-keeps-the-source-buffer-in-both-stacks ()
  (let ((my/completion-stack nil)
        (my/completion-stack-saved nil)
        (my/completion-stack-captured t)
        (my/completion-stack-native-reader completing-read-function)
        (my/completion-stack-native-completion-in-region-function
         completion-in-region-function)
        (my/completion-stack-native-xref-show-xrefs-function
         xref-show-xrefs-function)
        (my/completion-stack-native-xref-show-definitions-function
         xref-show-definitions-function)
        (ivy-mode nil)
        (ivy-do-completion-in-region t))
    (let ((original-require (symbol-function 'require)))
      (cl-letf (((symbol-function 'require)
                 (lambda (feature &optional filename noerror)
                   (if (eq feature 'ivy)
                       'ivy
                     (funcall original-require feature filename noerror))))
                ((symbol-function 'ivy-mode)
                 (lambda (enabled)
                   (setq ivy-mode (> enabled 0)
                         completing-read-function
                         (if ivy-mode
                             #'ivy-completing-read
                           my/completion-stack-native-reader)))))
        (dolist (stack '(native-consult ivy-counsel))
          (save-window-excursion
            (let ((source (generate-new-buffer " *completion stack CAPF*")))
              (unwind-protect
                  (progn
                    (my/set-completion-stack stack)
                    (switch-to-buffer source)
                    (insert "al")
                    (setq-local completion-at-point-functions
                                (list (lambda ()
                                        (list (point-min) (point-max)
                                              '("alpha" "alpine" "beta")))))
                    (let ((completion-auto-select nil))
                      (should (completion-at-point))
                      (completion-help-at-point))
                    (let ((window (get-buffer-window "*Completions*")))
                      (should (window-live-p window))
                      (with-current-buffer (window-buffer window)
                        (should (eq completion-reference-buffer source))))
                    (completion-in-region-mode -1))
                (let ((completion-buffer (get-buffer "*Completions*")))
                  (when completion-buffer
                    (kill-buffer completion-buffer)))
                (with-current-buffer source
                  (when completion-in-region-mode
                    (completion-in-region-mode -1)))
                (kill-buffer source)))))))))

(ert-deftest my/completion-stack-facades-dispatch-interactively ()
  (let (called)
    (cl-letf (((symbol-function 'execute-extended-command)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'execute-extended-command argument))))
              ((symbol-function 'counsel-M-x)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'counsel-M-x argument))))
              ((symbol-function 'isearch-forward)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'isearch-forward argument))))
              ((symbol-function 'swiper-isearch)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'swiper-isearch argument))))
              ((symbol-function 'consult-yank-from-kill-ring)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'consult-yank-from-kill-ring argument))))
              ((symbol-function 'counsel-yank-pop)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'counsel-yank-pop argument))))
              ((symbol-function 'consult-imenu)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'consult-imenu argument))))
              ((symbol-function 'counsel-imenu)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'counsel-imenu argument))))
              ((symbol-function 'consult-recent-file)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'consult-recent-file argument))))
              ((symbol-function 'counsel-recentf)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'counsel-recentf argument))))
              ((symbol-function 'consult-isearch-history)
               (lambda (&optional argument)
                 (interactive "P")
                 (setq called (list 'consult-isearch-history argument)))))
      (dolist (case '((my/select-command execute-extended-command counsel-M-x)
                      (my/search-incremental isearch-forward swiper-isearch)
                      (my/select-kill-ring
                       consult-yank-from-kill-ring counsel-yank-pop)
                      (my/select-imenu consult-imenu counsel-imenu)
                      (my/select-recent-file consult-recent-file counsel-recentf)
                      (my/select-isearch-history
                       consult-isearch-history consult-isearch-history)))
        (dolist (stack '(native-consult ivy-counsel))
          (let ((my/completion-stack stack)
                (current-prefix-arg '(4)))
            (setq called nil)
            (call-interactively (car case))
            (should (equal called
                           (list (if (eq stack 'ivy-counsel)
                                     (nth 2 case)
                                   (nth 1 case))
                                 '(4))))))))))

(ert-deftest my/completion-stack-native-adapter-restores-ivy-state ()
  (let ((ivy-mode t)
        (completing-read-function #'ivy-completing-read)
        observed)
    (should
     (eq (my/call-with-native-completion
          (lambda ()
            (setq observed (list ivy-mode completing-read-function))
            'success))
         'success))
    (should (equal observed '(nil completing-read-default)))
    (should ivy-mode)
    (should (eq completing-read-function #'ivy-completing-read))
    (should-error
     (my/call-with-native-completion
      (lambda ()
        (should-not ivy-mode)
        (should (eq completing-read-function #'completing-read-default))
        (error "expected adapter failure"))))
    (should ivy-mode)
    (should (eq completing-read-function #'ivy-completing-read))))

(ert-deftest my/completion-stack-and-transient-values-persist-across-emacs ()
  (let* ((root (make-temp-file "my-completion-stack-persistence-" t))
         (savehist-file (expand-file-name "savehist" root))
         (transient-values-file (expand-file-name "transient-values" root))
         (child-one-home (file-name-as-directory
                          (expand-file-name "child-one" root)))
         (child-two-home (file-name-as-directory
                          (expand-file-name "child-two" root)))
         (emacs (expand-file-name invocation-name invocation-directory))
         (setup
          `(progn
             (setq savehist-file ,savehist-file
                   transient-values-file ,transient-values-file)
             (add-to-list 'load-path ,my/completion-stack-test-directory)
             (defvar ivy-mode nil)
             (defvar ivy-do-completion-in-region nil)
             (defvar ivy-minibuffer-map (make-sparse-keymap))
             (defun ivy-completing-read (&rest arguments)
               (apply #'completing-read-default arguments))
             (defun ivy-mode (enabled)
               (setq ivy-mode (> enabled 0)
                     completing-read-function
                     (if ivy-mode
                         #'ivy-completing-read
                       #'completing-read-default)))
             (require 'my-completion-stack)
             (require 'my-file-picker)
             (require 'my-search)
             (require 'savehist)
             (add-to-list 'savehist-additional-variables
                          'my/completion-stack-saved)
             (savehist-mode 1)
             (defun my/completion-stack-test-child-set (stack)
               (let ((original-require (symbol-function 'require)))
                 (cl-letf (((symbol-function 'require)
                            (lambda (feature &optional filename noerror)
                              (if (eq feature 'ivy)
                                  'ivy
                                (funcall original-require feature filename noerror)))))
                   (my/set-completion-stack stack))))))
         (child-one
          `(let ((user-emacs-directory ,child-one-home))
             ,setup
             (my/completion-stack-test-child-set 'ivy-counsel)
             (my/file-picker-fzf-menu)
             (cl-letf (((symbol-function 'transient-infix-read)
                        (lambda (&rest arguments)
                          (ignore arguments)
                          "sensitive")))
               (execute-kbd-macro (kbd "c")))
             (transient-save)
             (transient-quit-all)
             (my/search-ripgrep-menu)
             (cl-letf (((symbol-function 'transient-infix-read)
                        (lambda (&rest arguments)
                          (ignore arguments)
                          "smart")))
               (execute-kbd-macro (kbd "c")))
             (transient-save)
             (transient-quit-all)
             (savehist-save)
             (princ "phase5-child-one-complete")))
         (child-two
          `(let ((user-emacs-directory ,child-two-home))
             ,setup
             (my/completion-stack-test-child-set
              (if (memq my/completion-stack-saved my/completion-stack-values)
                  my/completion-stack-saved
                my/completion-stack-default))
             (unless (and (eq my/completion-stack 'ivy-counsel)
                          (eq my/completion-stack-saved 'ivy-counsel))
               (error "Saved completion stack was not applied"))
             (unless (equal (transient-args 'my/file-picker-fzf-menu)
                            '("--case=sensitive" "--no-ignore" "--hidden"
                              "--root=project"))
               (error "File picker did not restore its saved values"))
             (unless (equal (transient-args 'my/search-ripgrep-menu)
                            '("--context=0" "--matching=regexp" "--case=smart"
                              "--no-ignore" "--hidden" "--root=project"))
               (error "Ripgrep did not restore its family-specific values"))
             (my/file-picker-fzf-menu)
             (cl-letf (((symbol-function 'transient-infix-read)
                        (lambda (&rest arguments)
                          (ignore arguments)
                          "smart")))
               (execute-kbd-macro (kbd "c")))
             (execute-kbd-macro (kbd "C-g"))
             (unless (equal (transient-args 'my/file-picker-fzf-menu)
                            '("--case=sensitive" "--no-ignore" "--hidden"
                              "--root=project"))
               (error "Cancel overwrote saved file picker values"))
             (my/file-picker-fzf-menu)
             (transient-reset)
             (transient-quit-all)
             (my/search-ripgrep-menu)
             (transient-reset)
             (transient-quit-all)
             (unless (equal (sort (copy-sequence
                                   (transient-args 'my/file-picker-fzf-menu))
                                  #'string<)
                            (sort (copy-sequence my/file-picker-fzf-default-args)
                                  #'string<))
               (error "File picker reset did not restore code defaults"))
             (unless (equal (sort (copy-sequence
                                   (transient-args 'my/search-ripgrep-menu))
                                  #'string<)
                            (sort (copy-sequence my/search-ripgrep-default-args)
                                  #'string<))
               (error "Ripgrep reset did not restore code defaults"))
             (when (or (assoc 'my/file-picker-fzf-menu transient-values)
                       (assoc 'my/search-ripgrep-menu transient-values))
               (error "Transient reset did not remove saved values"))
             (princ "phase5-child-two-complete"))))
    (unwind-protect
        (dolist (child `((,child-one . "phase5-child-one-complete")
                         (,child-two . "phase5-child-two-complete")))
          (with-temp-buffer
            (let ((status
                   (process-file emacs nil t nil
                                 "--batch" "-Q"
                                 "-L" my/completion-stack-test-directory
                                 "--eval" (prin1-to-string (car child)))))
              (unless (= status 0)
                (error "Persistence child failed: %s" (buffer-string)))
              (should (string-match-p (cdr child) (buffer-string))))))
      (delete-directory root t))))

(ert-deftest my/completion-stack-configures-ivy-minibuffer-collect-bindings ()
  (let ((my/ivy-minibuffer-map-configured nil)
        (ivy-minibuffer-map (make-sparse-keymap)))
    ;; Ivy owns C-c C-o upstream; the profile adds the equivalent C-q.
    (keymap-set ivy-minibuffer-map "C-c C-o" #'ivy-occur)
    (my/configure-ivy-minibuffer-map)
    (should my/ivy-minibuffer-map-configured)
    (should (eq (keymap-lookup ivy-minibuffer-map "C-q") #'ivy-occur))
    (should (eq (keymap-lookup ivy-minibuffer-map "C-c C-o") #'ivy-occur))
    (keymap-set ivy-minibuffer-map "C-q" #'ignore)
    (my/configure-ivy-minibuffer-map)
    (should (eq (keymap-lookup ivy-minibuffer-map "C-q") #'ignore))
    (should (eq (keymap-lookup ivy-minibuffer-map "C-c C-o") #'ivy-occur))
    (should (eq (keymap-lookup global-map "C-q") #'quoted-insert))))

;;; my-completion-stack-test.el ends here
