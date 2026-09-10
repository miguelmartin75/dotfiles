;;; my-completion-stack-test.el --- Tests for completion stack lifecycle -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'package)

(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name)))
(require 'my-completion-stack)

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
    (let (activity)
      (let ((make-process-advice
             (lambda (&rest _arguments) (push 'make-process activity)))
            (start-process-advice
             (lambda (&rest _arguments) (push 'start-process activity)))
            (refresh-advice
             (lambda (&rest _arguments)
               (push 'package-refresh-contents activity)))
            (install-advice
             (lambda (&rest _arguments) (push 'package-install activity))))
        (unwind-protect
            (progn
              (advice-add 'make-process :before make-process-advice)
              (advice-add 'start-process :before start-process-advice)
              (advice-add 'package-refresh-contents :before refresh-advice)
              (advice-add 'package-install :before install-advice)
              (my/set-completion-stack 'native-consult)
              (my/set-completion-stack 'ivy-counsel)
              (my/set-completion-stack 'native-consult)
              (should-not activity))
          (advice-remove 'make-process make-process-advice)
          (advice-remove 'start-process start-process-advice)
          (advice-remove 'package-refresh-contents refresh-advice)
          (advice-remove 'package-install install-advice))))))

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

(ert-deftest my/completion-stack-configures-only-ivy-minibuffer-collect ()
  (let ((my/ivy-minibuffer-map-configured nil)
        (ivy-minibuffer-map (make-sparse-keymap)))
    (my/configure-ivy-minibuffer-map)
    (should my/ivy-minibuffer-map-configured)
    (should (eq (keymap-lookup ivy-minibuffer-map "C-q") #'ivy-occur))
    (keymap-set ivy-minibuffer-map "C-q" #'ignore)
    (my/configure-ivy-minibuffer-map)
    (should (eq (keymap-lookup ivy-minibuffer-map "C-q") #'ignore))
    (should (eq (keymap-lookup global-map "C-q") #'quoted-insert))))

;;; my-completion-stack-test.el ends here
