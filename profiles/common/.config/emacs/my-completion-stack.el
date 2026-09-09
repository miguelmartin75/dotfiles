;;; my-completion-stack.el --- Runtime completion stack selection -*- lexical-binding: t; -*-

(require 'seq)
(require 'transient)
(require 'xref)

(defvar ivy-do-completion-in-region)

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

(unless my/completion-stack-captured
  (setq my/completion-stack-native-reader completing-read-function
        my/completion-stack-native-completion-in-region-function
        completion-in-region-function
        my/completion-stack-native-xref-show-xrefs-function
        xref-show-xrefs-function
        my/completion-stack-native-xref-show-definitions-function
        xref-show-definitions-function
        my/completion-stack-captured t))

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
        (error
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
