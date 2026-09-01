;; Provision packages outside normal Emacs startup.  -*- lexical-binding: t; -*-
(require 'package)
(require 'package-vc)
(require 'seq)

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
           "0815dbea006128df1d61e9d29e5a8ada53b349c1")
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
        (mapcar (lambda (entry)
                  (cons (car entry) (cadr entry)))
                vc-packages))
       (custom-state-file (make-temp-file "emacs-package-custom-" nil ".el"))
       (custom-file custom-state-file))
  (unwind-protect
      (progn
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
                  yasnippet              ; Eglot completion placeholders only
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
    (delete-file custom-state-file)))
