;;; my-completion-stack.el --- Runtime completion stack selection -*- lexical-binding: t; -*-

(require 'seq)
(require 'transient)
(require 'xref)

(defvar ivy-do-completion-in-region)
(defvar ivy-height)
(defvar ivy-height-alist)
(defvar ivy-minibuffer-map)
(defvar ivy-mode)

(declare-function consult-imenu "consult")
(declare-function consult-isearch-history "consult")
(declare-function consult-recent-file "consult")
(declare-function consult-xref "consult-xref")
(declare-function consult-yank-from-kill-ring "consult")
(declare-function counsel-M-x "counsel")
(declare-function counsel-imenu "counsel")
(declare-function counsel-recentf "counsel")
(declare-function counsel-yank-pop "counsel")
(declare-function embark-collect "embark")
(declare-function ivy-completing-read "ivy")
(declare-function ivy-configure "ivy" (caller &rest arguments))
(declare-function ivy-mode "ivy")
(declare-function ivy-occur "ivy")
(declare-function swiper-isearch "swiper")

(defconst my/completion-stack-default 'native-consult
  "Completion stack applied when no saved preference is valid.")

(defconst my/completion-stack-values '(native-consult ivy-counsel)
  "Supported completion stack values.")

(defvar my/completion-stack nil
  "Completion stack whose frontend and Xref state is currently applied.")

(defvar my/completion-stack-saved nil
  "Completion stack preference restored and persisted by Savehist.")

(defvar my/completion-stack-captured nil
  "Whether the native completion and Xref state has been captured.")

(defvar my/completion-stack-native-reader nil
  "Native value of `completing-read-function'.")

(defvar my/completion-stack-native-completion-in-region-function nil
  "Native value of `completion-in-region-function'.")

(defvar my/completion-stack-native-xref-show-xrefs-function nil
  "Native value of `xref-show-xrefs-function'.")

(defvar my/completion-stack-native-xref-show-definitions-function nil
  "Native value of `xref-show-definitions-function'.")

(defvar my/completion-stack-which-key-configured nil
  "Whether dynamic Which Key descriptions have been registered.")

(defvar my/ivy-minibuffer-map-configured nil
  "Whether profile-owned Ivy minibuffer bindings have been installed.")

(defconst my/ivy-occur-display-buffer-rule
  '("\\`\\*ivy-occur\\(?: .+\\)?\\*\\(?:<[0-9]+>\\)?\\'"
    (display-buffer-same-window display-buffer-reuse-window))
  "Display Ivy Occur results in the window that launched the reader.")

(unless my/completion-stack-captured
  (setq my/completion-stack-native-reader completing-read-function
        my/completion-stack-native-completion-in-region-function
        completion-in-region-function
        my/completion-stack-native-xref-show-xrefs-function
        xref-show-xrefs-function
        my/completion-stack-native-xref-show-definitions-function
        xref-show-definitions-function
        my/completion-stack-captured t))

(defun my/configure-ivy-minibuffer-map ()
  "Install the profile-owned Ivy minibuffer bindings once."
  (unless my/ivy-minibuffer-map-configured
    (keymap-set ivy-minibuffer-map "C-q" #'embark-collect)
    (setq my/ivy-minibuffer-map-configured t)))

(defun my/configure-ivy ()
  "Apply the profile-owned Ivy settings."
  (my/configure-ivy-minibuffer-map)
  (setq ivy-height 14)
  (add-to-list 'display-buffer-alist my/ivy-occur-display-buffer-rule))

(with-eval-after-load 'ivy
  (my/configure-ivy))

(defun my/configure-counsel ()
  "Apply the profile-owned Counsel settings."
  (ivy-configure 'counsel-M-x :initial-input ""))

(with-eval-after-load 'counsel
  (my/configure-counsel))

(defun my/set-completion-stack (stack)
  "Apply completion STACK without changing in-buffer completion.

STACK must be `native-consult' or `ivy-counsel'.  A transition is rejected
while a minibuffer, completion-in-region session, or Transient is active."
  (interactive
   (list
    (intern
     (completing-read "Completion stack: "
                      (mapcar #'symbol-name my/completion-stack-values)
                      nil t))))
  (unless (memq stack my/completion-stack-values)
    (user-error "Unsupported completion stack: %S" stack))
  (unless (eq stack my/completion-stack)
    (when (or (active-minibuffer-window)
              (seq-some
               (lambda (buffer)
                 (buffer-local-value 'completion-in-region-mode buffer))
               (buffer-list))
              (transient-active-prefix))
      (user-error "Finish the active completion or Transient before switching stacks"))
    (let ((previous-stack my/completion-stack)
          (previous-saved my/completion-stack-saved)
          (previous-ivy-mode (bound-and-true-p ivy-mode))
          (previous-reader completing-read-function)
          (previous-completion-in-region-function completion-in-region-function)
          (previous-xref-show-xrefs-function xref-show-xrefs-function)
          (previous-xref-show-definitions-function
           xref-show-definitions-function))
      (condition-case condition
          (progn
            (if (eq stack 'ivy-counsel)
                (progn
                  (require 'ivy)
                  (setq ivy-do-completion-in-region nil)
                  (unless (eq completion-in-region-function
                              my/completion-stack-native-completion-in-region-function)
                    (error "Ivy activation would replace native completion-in-region"))
                  (ivy-mode 1)
                  (unless (and (eq completing-read-function
                                   #'ivy-completing-read)
                               (eq completion-in-region-function
                                   my/completion-stack-native-completion-in-region-function))
                    (error "Ivy did not preserve the completion frontend contract"))
                  (setq xref-show-xrefs-function
                        my/completion-stack-native-xref-show-xrefs-function
                        xref-show-definitions-function
                        my/completion-stack-native-xref-show-definitions-function))
              (when (bound-and-true-p ivy-mode)
                (ivy-mode -1))
              (unless (and (eq completing-read-function
                               my/completion-stack-native-reader)
                           (eq completion-in-region-function
                               my/completion-stack-native-completion-in-region-function))
                (error "Native completion frontend was not restored"))
              (setq xref-show-xrefs-function #'consult-xref
                    xref-show-definitions-function #'consult-xref))
            (setq my/completion-stack stack
                  my/completion-stack-saved stack))
        ((error quit)
         (condition-case nil
             (if previous-ivy-mode
                 (progn
                   (require 'ivy)
                   (setq ivy-do-completion-in-region nil)
                   (ivy-mode 1))
               (when (fboundp 'ivy-mode)
                 (ivy-mode -1)))
           (error
            (setq ivy-mode previous-ivy-mode)))
         (setq completing-read-function previous-reader
               completion-in-region-function
               previous-completion-in-region-function
               xref-show-xrefs-function previous-xref-show-xrefs-function
               xref-show-definitions-function
               previous-xref-show-definitions-function
               my/completion-stack previous-stack
               my/completion-stack-saved previous-saved)
         (signal (car condition) (cdr condition)))))))

(defun my/call-with-native-completion (function &rest arguments)
  "Call FUNCTION with ARGUMENTS while the native minibuffer owns completion."
  (let ((ivy-mode nil)
        (completing-read-function #'completing-read-default))
    (apply function arguments)))

(defun my/dispatch-completion-stack-command (native-command ivy-command)
  "Interactively call NATIVE-COMMAND or IVY-COMMAND for the applied stack."
  (call-interactively
   (if (eq my/completion-stack 'ivy-counsel)
       ivy-command
     native-command)))

(defun my/select-command ()
  "Select and run a command with the applied completion stack."
  (interactive)
  (my/dispatch-completion-stack-command
   #'execute-extended-command #'counsel-M-x))

(defun my/search-incremental ()
  "Search incrementally in the current buffer with the applied stack."
  (interactive)
  (my/dispatch-completion-stack-command #'isearch-forward #'swiper-isearch))

(defun my/select-kill-ring ()
  "Select a kill-ring entry with the applied completion stack."
  (interactive)
  (my/dispatch-completion-stack-command
   #'consult-yank-from-kill-ring #'counsel-yank-pop))

(defun my/select-imenu ()
  "Select an Imenu entry with the applied completion stack."
  (interactive)
  (my/dispatch-completion-stack-command #'consult-imenu #'counsel-imenu))

(defun my/select-recent-file ()
  "Select a recent file with the applied completion stack."
  (interactive)
  (my/dispatch-completion-stack-command #'consult-recent-file #'counsel-recentf))

(defun my/select-isearch-history ()
  "Select an Isearch history entry with native Consult presentation."
  (interactive)
  (if (eq my/completion-stack 'ivy-counsel)
      (my/call-with-native-completion
       #'call-interactively #'consult-isearch-history)
    (call-interactively #'consult-isearch-history)))

(defun my/toggle-completion-stack ()
  "Toggle between the native Consult and Ivy Counsel completion stacks."
  (interactive)
  (my/set-completion-stack
   (if (eq my/completion-stack 'native-consult)
       'ivy-counsel
     'native-consult)))

(defun my/select-native-completion-stack ()
  "Select the native Consult completion stack."
  (interactive)
  (my/set-completion-stack 'native-consult))

(defun my/select-ivy-completion-stack ()
  "Select the Ivy Counsel completion stack."
  (interactive)
  (my/set-completion-stack 'ivy-counsel))

(defun my/completion-stack-which-key-description (binding)
  "Add the applied completion stack to Which Key BINDING."
  (cons (car binding)
        (format "toggle completion stack (%s)"
                (or my/completion-stack my/completion-stack-default))))

(transient-define-prefix my/completion-stack-menu ()
  "Select the active completion stack."
  ["Completion stack"
   ("n" "Native and Consult" my/select-native-completion-stack)
   ("i" "Ivy and Counsel" my/select-ivy-completion-stack)
   ("t" "Toggle" my/toggle-completion-stack)])

(provide 'my-completion-stack)

;;; my-completion-stack.el ends here
