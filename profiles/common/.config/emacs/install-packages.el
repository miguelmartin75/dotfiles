;; Provision packages outside normal Emacs startup.  -*- lexical-binding: t; -*-
(require 'package)
(require 'package-vc)
(require 'seq)

(defconst my/reviewed-completion-vc-packages
  '((ivy
     (ivy :url "https://github.com/abo-abo/swiper.git")
     "0d02f5063d36ff4fa6138f0973c83c6d3874fba0")
    (counsel
     (counsel :url "https://github.com/abo-abo/swiper.git")
     "0d02f5063d36ff4fa6138f0973c83c6d3874fba0")
    (swiper
     (swiper :url "https://github.com/abo-abo/swiper.git")
     "0d02f5063d36ff4fa6138f0973c83c6d3874fba0")
    (consult
     (consult :url "https://github.com/minad/consult.git")
     "1b217ca2fb8bcfc4bb56feef829d1bb2b61c85b1")
    (embark
     (embark :url "https://github.com/oantolin/embark.git")
     "87e53827cf6659dcc4ac4e54be9af34aeca44f6e")
    (embark-consult
     (embark-consult :url "https://github.com/oantolin/embark.git")
     "87e53827cf6659dcc4ac4e54be9af34aeca44f6e")
    (transient
     (transient :url "https://github.com/magit/transient.git")
     "03c8ccc6aab24021787aada2be12d64cb1f436e8"))
  "Reviewed VC specifications for every direct completion dependency.")

(defvar my/install-packages-run-entrypoint t
  "Whether loading this file runs its batch provisioning entrypoint.")

(defun my/provision-reviewed-completion-vc-packages ()
  "Provision and validate the reviewed direct completion dependencies."
  (let ((validation-errors nil)
        (accepted-packages nil))
    (dolist (entry my/reviewed-completion-vc-packages)
      (let* ((name (nth 0 entry))
             (spec (nth 1 entry))
             (revision (nth 2 entry))
             (installed-descriptors (alist-get name package-alist))
             (vc-descriptors
              (seq-filter #'package-vc-p installed-descriptors))
             install-error)
        (when (null vc-descriptors)
          (condition-case err
              (package-vc-install spec revision)
            (error
             (setq install-error (error-message-string err)))))

        (setq installed-descriptors (alist-get name package-alist))
        (let* ((vc-descriptors
                (seq-filter #'package-vc-p installed-descriptors))
               (vc-commits (mapcar #'package-vc-commit vc-descriptors))
               (distinct-vc-commits (delete-dups (copy-sequence vc-commits))))
          (cond
           ((null vc-descriptors)
            (push (format "%s: %s after package-vc-install%s; expected a VC descriptor at %s"
                          name
                          (if installed-descriptors
                              "archive-only"
                            (if (package-get-descriptor name 'builtin)
                                "builtin-only"
                              "missing"))
                          (if install-error
                              (format " (%s)" install-error)
                            "")
                          revision)
                  validation-errors))
           ((cdr distinct-vc-commits)
            (push (format "%s: conflicting VC revisions %s; expected reviewed revision %s"
                          name distinct-vc-commits revision)
                  validation-errors))
           ((not (equal (car distinct-vc-commits) revision))
            (push (format "%s: VC revision %s does not match reviewed revision %s"
                          name (car distinct-vc-commits) revision)
                  validation-errors))
           (t
            (push (list name revision) accepted-packages))))))

    (if validation-errors
        (error (concat
                "Reviewed completion VC package validation failed:\n"
                (mapconcat #'identity (nreverse validation-errors) "\n")
                "\nCorrect the listed VC installations, then rerun "
                "emacs --batch -l profiles/common/.config/emacs/install-packages.el"))
      (dolist (package (nreverse accepted-packages))
        (princ (format "PACKAGE_VC_ACCEPTED %s %s\n"
                       (nth 0 package) (nth 1 package)))))))

(defun my/install-packages ()
  "Provision archive packages and reviewed VC packages for this profile."
  (setq package-archives '(("melpa" . "https://melpa.org/packages/")
                           ("elpa" . "https://elpa.gnu.org/packages/")))
  (package-initialize)

  (let* ((vc-packages
          '((ghostel
             ;; Native PTY renderer, compilation UI, and terminal-aware public sends.
             (:url "https://github.com/dakra/ghostel.git")
             "94eace59046c275d6c8f3c065489f6bbdb4f037b")
            (evil-ghostel
             ;; Evil state integration for Ghostel terminal buffers.
             (:url "https://github.com/dakra/ghostel.git"
              :lisp-dir "extensions/evil-ghostel")
             "94eace59046c275d6c8f3c065489f6bbdb4f037b")
            (term-sessions
             ;; Durable zmx sessions and Emacs/Org interfaces.
             (:url "https://github.com/ArthurHeymans/emacs-term-sessions.git")
             "acc872676ad2476187984056e7896aa0ea2b2dfc")
            (diff-hl
             ;; Source-buffer Git hunk state and actions.
             (:url "https://github.com/dgutov/diff-hl.git")
             "3d9552c575fd14ac98ac97bf3c19cdef39f79305")
            (markdown-table-wrap
             ;; Display-only wrapped Org and Markdown table cells.
             (:url "https://github.com/dnouri/markdown-table-wrap.git")
             "f846b77d13f34fba57c80214c1a61e00c94048a3")
            (odin-mode
             ;; Odin editing mode for the retained language surface.
             (:url "https://github.com/mattt-b/odin-mode.git")
             "21c6ff8b49f5eaa2d3b9969feeb08de921f11e92")))
         (vc-packages
          (if (executable-find "difft")
              (append
               vc-packages
               '((difftastic
                  ;; Optional structural diffs in Magit when difft is installed.
                  (:url "https://github.com/pkryger/difftastic.el.git")
                  "f94076985ba46bf629abc9615c9b1fefcc3390ef")))
            vc-packages))
         (package-vc-selected-packages
          (append
           (mapcar (lambda (entry)
                     (cons (car entry) (cdr (cadr entry))))
                   my/reviewed-completion-vc-packages)
           (mapcar (lambda (entry)
                     (cons (car entry) (cadr entry)))
                   vc-packages)))
         (custom-state-file (make-temp-file "emacs-package-custom-" nil ".el"))
         (custom-file custom-state-file))
    (unwind-protect
        (progn
          ;; Completion dependencies precede archive packages, including Magit.
          (my/provision-reviewed-completion-vc-packages)

          (let ((missing-packages
                 (seq-remove
                  #'package-installed-p
                  '(dape                   ; explicit DAP launch and attach
                    evil                   ; modal editing core
                    evil-better-visual-line ; display-line motions
                    evil-collection        ; Evil keys in retained modes
                    evil-numbers           ; explicit number increment/decrement
                    evil-org               ; modal Org editing and agenda
                    evil-surround          ; modal delimiter editing
                    evil-visualstar        ; visual selection search
                    exec-path-from-shell   ; GUI shell PATH import
                    gptel                  ; explicit AI conversations and edits
                    gscholar-bibtex        ; bibliography discovery
                    load-env-vars          ; personal secrets/environment files
                    magit                  ; Git status and review workflow
                    markdown-mode          ; Markdown fallback and prose editing
                    nim-mode               ; Nim editing and Eglot mode identity
                    ob-async               ; explicit asynchronous Org Babel blocks
                    olivetti               ; focused prose layout
                    org-fragtog            ; live Org LaTeX fragment previews
                    org-ref                ; citation insertion and source opening
                    org-roam               ; personal linked-note graph
                    org-roam-bibtex        ; bibliography-backed Roam notes
                    php-mode               ; PHP editing and indentation
                    zig-mode))))           ; Zig editing and Eglot mode identity
            (when missing-packages
              (package-refresh-contents))
            (dolist (package missing-packages)
              (package-install package)))

          (dolist (entry vc-packages)
            (let* ((name (car entry))
                   (spec (cadr entry))
                   (revision (caddr entry))
                   (installed (package-get-descriptor name 'installed
                                                      #'package-vc-p)))
              (if installed
                  (unless (equal (package-vc-commit installed) revision)
                    (error "%s is installed at %s instead of reviewed revision %s"
                           name (package-vc-commit installed) revision))
                (package-vc-install (cons name spec) revision))

              (setq installed
                    (package-get-descriptor name 'installed #'package-vc-p))
              (unless (and installed
                           (equal (package-vc-commit installed) revision))
                (error "%s was not installed at reviewed revision %s"
                       name revision))))

          (princ "PACKAGES_INSTALLED\n"))
      (delete-file custom-state-file))))

(when my/install-packages-run-entrypoint
  (my/install-packages))
