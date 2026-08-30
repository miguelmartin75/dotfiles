;; SECTION: fundamental  -*- lexical-binding: t; -*-
;; Fresh machines require Emacs 31.1+ with modules and native Tree-sitter, Git,
;; a C/C++ compiler and linker, ripgrep (`rg'), zmx, aspell, multimarkdown,
;; LaTeX, dvisvgm, and the selected language servers: clangd, rust-analyzer,
;; lua-language-server, ty, typescript-language-server, zls, nimlangserver, and
;; ols.  Difftastic (`difft') is optional and enables structural Magit diffs.
;; After linking this profile into ~/.config, provision it explicitly in this
;; order:
;; emacs --batch -Q -l ~/.config/emacs/install-packages.el
;; emacs --batch -Q -l ~/.config/emacs/install-tree-sitter-grammars.el
;; Then install Ghostel's native module with `M-x ghostel-download-module' or,
;; with Zig available, `M-x ghostel-module-compile'.  Normal startup and the
;; first terminal use remain offline and never install software implicitly.
(require 'package)

(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(require 'use-package)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("5c7720c63b729140ed88cf35413f36c728ab7c70f8cd8422d9ee1cedeb618de5"
     "87fa3605a6501f9b90d337ed4d832213155e3a2e36a512984f83e847102a42f4"
     "b5fd9c7429d52190235f2383e47d340d7ff769f141cd8f9e7a4629a81abc6b19"
     "921f165deb8030167d44eaa82e85fcef0254b212439b550a9b6c924f281b5695"
     "7ec8fd456c0c117c99e3a3b16aaf09ed3fb91879f6601b1ea0eeaee9c6def5d9"
     "166a2faa9dc5b5b3359f7a31a09127ebf7a7926562710367086fcc8fc72145da"
     "a9eeab09d61fef94084a95f82557e147d9630fbbb82a837f971f83e66e21e5ad"
     "2ab8cb6d21d3aa5b821fa638c118892049796d693d1e6cd88cb0d3d7c3ed07fc"
     "e14289199861a5db890065fdc5f3d3c22c5bac607e0dbce7f35ce60e6b55fc52"
     "7e068da4ba88162324d9773ec066d93c447c76e9f4ae711ddd0c5d3863489c52"
     "1a1ac598737d0fcdc4dfab3af3d6f46ab2d5048b8e72bc22f50271fd6d393a00"
     "d268b67e0935b9ebc427cad88ded41e875abfcc27abd409726a92e55459e0d01"
     "1704976a1797342a1b4ea7a75bdbb3be1569f4619134341bd5a4c1cfb16abad4"
     "7a7b1d475b42c1a0b61f3b1d1225dd249ffa1abb1b7f726aec59ac7ca3bf4dae"
     "37768a79b479684b0756dec7c0fc7652082910c37d8863c35b702db3f16000f8"
     default))
 '(org-agenda-files '("/Users/migmartin/org/journal.org"))
 '(tramp-completion-reread-directory-timeout nil)
 '(tramp-default-method "sshx")
 '(tramp-use-connection-share nil)
 '(warning-suppress-log-types
   '((org-element org-element-cache) (org-element org-element-parser)
     (comp))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; backup files
(let ((backup-dir "~/tmp/emacs/backups")
      (auto-saves-dir "~/tmp/emacs/auto-saves/"))
  (dolist (dir (list backup-dir auto-saves-dir))
    (when (not (file-directory-p dir))
      (make-directory dir t)))
  (setq backup-directory-alist `(("." . ,backup-dir)) auto-save-file-name-transforms `((".*" ,auto-saves-dir t))
        auto-save-list-file-prefix (concat auto-saves-dir ".saves-")
        tramp-backup-directory-alist `((".*" . ,backup-dir))
        tramp-auto-save-directory auto-saves-dir))

(setq backup-by-copying t    ; Don't delink hardlinks
      delete-old-versions t  ; Clean up the backups
      version-control t      ; Use version numbers on backups,
      kept-new-versions 5    ; keep some new versions
      kept-old-versions 3)   ; and some old ones, too

(add-hook 'before-save-hook 'delete-trailing-whitespace)
(setq require-final-newline t)


(setq gc-cons-threshold (* 1000 1024 1024)
      read-process-output-max (* 1024 1024)
)

(save-place-mode 1)


;; https://www.fromkk.com/posts/preview-latex-in-org-mode-with-emacs-in-macos/
(use-package exec-path-from-shell
  :config (exec-path-from-shell-initialize)
)
(use-package load-env-vars
  :config
  (load-env-vars "~/.secrets")
  (load-env-vars "~/.zshrc")
)

(setq config-path "~/.config/emacs/init.el")

(electric-indent-mode)
(use-package magit
  :commands magit-status)
(when (and (executable-find "difft")
           (package-installed-p 'difftastic))
  (require 'difftastic-bindings)
  (setq difftastic-bindings-alist
        '((((prefixes . ((magit-diff (-1 -1) magit-diff))))
           . (("M-d" difftastic-magit-diff "Difftastic diff (dwim)")
              ("M-c" difftastic-magit-show "Difftastic show")))
          (((prefixes . ((magit-blame "b" magit-blame)))
            (keymaps . ((magit-blame-read-only-mode-map . magit-blame))))
           . (("M-RET" difftastic-magit-show "Difftastic show")))
          (((prefixes . ((magit-file-dispatch (0 1 -1) magit-files))))
           . (("M-d" difftastic-magit-diff-buffer-file "Difftastic")))))
  (difftastic-bindings-mode 1))
(setq server-kill-new-buffers t)

(use-package org
    :config
  (setq org-todo-keywords
	'((sequence "PROJ(P!)" "TODO(t!)" "REVIEW(r!)" "POST(p!)" "DOING(d!)" "BLOCKED(b!)" "|" "DONE(f!)" "CANCELED(c!@)"))
  )
  (setq org-capture-templates
	'(
    ("r" "Reflections")
    ("rw" "Weekly Reflection" entry
    (file+datetree "~/org/reflections.org")
    (file "~/org/templates/weekly.org")
    :empty-lines 1
    :tree-type week
    :clock-in t :clock-resume t
    ; :after-finalize my/remove-datetree-day-heading
    )
    ("rm" "Monthly Reflection" entry
    (file+datetree "~/org/reflections.org")
    (file "~/org/templates/monthly.org")
    :empty-lines 1
    :tree-type month
    :clock-in t :clock-resume t
    )

    ;; journal
	  ("m" "Meeting" entry (file+datetree "~/org/journal.org")
	   "* %T %? :meeting:work:" :empty-lines 1)
	  ("l" "Log" entry (file+datetree "~/org/journal.org")
	   "* %T %? :log:" :empty-lines 1)
	  ("t" "Add Task" entry (file+datetree "~/org/journal.org")
	   "* TODO %? \n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("T" "Add Work Task" entry (file+datetree "~/org/journal.org")
	   "* TODO %? :work:\n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("j" "Journal Entry" entry (file+datetree "~/org/journal.org")
	   "* %t :journal:\n%?" :empty-lines 1)

    ;; life
	  ("b" "Task: Backlog" entry (file+olp "~/org/life.org" "Backlog" "Inbox")
	   "* TODO %? :backlog:\n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("n" "Note" entry (file+olp "~/org/life.org" "Backlog" "Inbox")
	   "* %T %? :note:" :empty-lines 1)

	  ("i" "Idea" entry (file+olp "~/org/life.org" "Areas" "Ideas")
	   "* %? :inbox:idea:\nAdded: %U" :empty-lines 1)
	  ("w" "Writing Idea" entry (file+olp "~/org/life.org" "Areas" "Writing Ideas")
	   "* %? :writing:idea:\nAdded: %U" :empty-lines 1)
	  ("s" "Startup Idea" entry (file+olp "~/org/life.org" "Areas" "Startup Ideas")
	   "* %? :startup:idea:\nAdded: %U" :empty-lines 1)
	  ("R" "Research Idea" entry (file+olp "~/org/life.org" "Areas" "Research Ideas")
	   "* %? :research:idea:\nAdded: %U" :empty-lines 1)
    )
  )

  ; refiling
  (setq org-refile-targets '((nil :maxlevel . 9)))
  (setq org-outline-path-complete-in-steps nil)         ; Refile in a single go
  (setq org-refile-use-outline-path t)                  ; Show full paths for refiling

  (setq org-src-preserve-indentation t)
  (add-hook 'org-mode-hook (lambda () (electric-indent-mode -1)))

  (setq org-agenda-files '("~/org/life.org"))

  (setq org-log-into-drawer t)
  (setq org-tags-column 0)

  (setq org-adapt-indentation nil)
  (setq org-confirm-babel-evaluate nil)
  (setq org-hierarchical-todo-statistics t)
  (org-babel-do-load-languages 'org-babel-load-languages
      '(
          (shell . t)
          (python . t)
          (emacs-lisp . t)
          (C . t)
      )
  )

  (defun my/org-summary-todo (n-done n-not-done)
    "Set parent to DONE if all children are done, TODO if none, DOING otherwise."
    (let (org-log-done)  ;; suppress change logging
        (org-todo
        (cond ((= n-not-done 0)     "DONE")
            ((= n-done 0)         "TODO")
            (t                    "DOING")))))

  (add-hook 'org-after-todo-statistics-hook #'my/org-summary-todo)

  ;; Optional: For checkbox-based lists, update parent state too
  (defun my/org-summary-checkbox-cookie ()
    "Update parent TODO based on checkbox progress cookie."
    (let ((state (org-get-todo-state)))
        (when state
        (save-excursion
            (org-back-to-heading t)
            (end-of-line)
            (when (re-search-backward
                "\\[\\([0-9]*%\\)\\]\\|\\[\\([0-9]*\\)/\\([0-9]*\\)\\]" (line-beginning-position) t)
            (let ((p1 (match-string 1))
                    (n (match-string 2))
                    (m (match-string 3)))
                (cond
                (p1
                (cond ((string= p1 "100%") (org-todo-if-needed "DONE"))
                        ((string= p1 "0%")   (org-todo-if-needed "TODO"))
                        (t                    (org-todo-if-needed "DOING"))))
                ((and n m)
                (cond ((string= n m)    (org-todo-if-needed "DONE"))
                        ((or (string= n "") (string= n "0")) (org-todo-if-needed "TODO"))
                        (t                (org-todo-if-needed "DOING")))))))))))

  (add-hook 'org-checkbox-statistics-hook #'my/org-summary-checkbox-cookie)



)

(require 'org-tempo)

(use-package org-fragtog
  :hook (org-mode . org-fragtog-mode)
  :init
  (setq org-odt-pixels-per-inch 192.0
        org-preview-latex-default-process 'dvisvgm
        org-format-latex-options
        '(:foreground default :background default :scale 2.5
          :html-foreground "Black" :html-background "Transparent"
          :html-scale 1.0
          :matchers ("begin" "$1" "$" "$$" "\\(" "\\["))))

;; AI
(use-package gptel
  :commands (gptel gptel-rewrite gptel-send)
  :config
  (setq
    gptel-model 'claude-sonnet-4-20250514
    gptel-backend (
       gptel-make-anthropic
       "Claude"
       :stream t
       :models '(claude-sonnet-4-20250514)
       :key (getenv "ANTHROPIC_API_KEY")
    )
  )
)
(use-package org-roam
  :commands (org-roam-node-find org-roam-node-insert)
  :hook (after-init . org-roam-db-autosync-mode)
  :custom
  (org-roam-directory (file-truename "~/org/"))
  (org-roam-db-location "~/.org-roam.db")
  (org-roam-display-template
   (concat "${title:*} " (propertize "${tags:*}" 'face 'org-tag))))

;; research
(use-package org-ref
  :commands (org-ref-insert-cite-link
             org-ref-open-pdf-at-point
             org-ref-open-url-at-point))
(use-package org-roam-bibtex
  :after org-roam
  :commands org-roam-bibtex-mode
  :hook (org-roam-mode . org-roam-bibtex-mode)
  :config (require 'org-ref)
  :custom
  (orb-preformat-keywords
   '(("citekey" . "=key=")
     "title"
     "url"
     "author-or-editor-abbrev"
     "abstract"
     "author-or-editor"
     "keywords")))

(use-package gscholar-bibtex
  :commands gscholar-bibtex)


(use-package ob-async)

;; evil
(use-package evil
   :init
   (setq evil-want-integration t)
   (setq evil-want-keybinding nil)
   (setq evil-want-C-u-scroll t)
   (setq evil-want-C-i-jump t)
   (setq evil-want-C-w-delete t)
   (setq evil-want-C-w-in-emacs-state t)
   (setq evil-undo-system 'undo-redo)
   (setq-default evil-symbol-word-search t)

   :config
   (evil-mode 1)
   (define-key evil-insert-state-map (kbd "C-g") 'evil-normal-state)
   (define-key evil-insert-state-map (kbd "C-h") 'evil-delete-backward-char-and-join)
   (define-key evil-normal-state-map (kbd "gd") #'xref-find-definitions)
   (define-key evil-normal-state-map (kbd "gD") #'eglot-find-declaration)
   (define-key evil-normal-state-map (kbd "gi") #'eglot-find-implementation)
   (define-key evil-normal-state-map (kbd "K") #'eldoc-doc-buffer)
   (define-key evil-normal-state-map (kbd "[d") #'flymake-goto-prev-error)
   (define-key evil-normal-state-map (kbd "]d") #'flymake-goto-next-error)
   (evil-set-initial-state 'messages-buffer-mode 'normal)
   (setq evil-search-module 'evil-search)
   (evil-select-search-module 'evil-search-module 'evil-search)
   (evil-set-undo-system 'undo-redo)

   ;; minor mode
   (add-hook 'org-capture-mode-hook 'evil-insert-state)

   (global-visual-line-mode)
)

(use-package evil-visualstar :after evil :config (global-evil-visualstar-mode))

(use-package evil-surround
  :after evil
  :config
  (global-evil-surround-mode 1))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

(use-package evil-org
  :after org
  :config
  (add-hook 'org-mode-hook 'evil-org-mode)
  (add-hook 'evil-org-mode-hook
	      (lambda ()
		(evil-org-set-key-theme)))
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
)

(use-package evil-better-visual-line
  :config
  (evil-better-visual-line-on)
)

(use-package
  evil-numbers
  :config
  (evil-define-key '(normal visual) 'global (kbd "C-c +") 'evil-numbers/inc-at-pt)
  (evil-define-key '(normal visual) 'global (kbd "C-c -") 'evil-numbers/dec-at-pt)
)

;; terminal
(use-package ghostel
  :commands ghostel-project
  :init
  ;; Install the native module explicitly with `ghostel-download-module' or
  ;; `ghostel-module-compile'; terminal use never installs it implicitly.
  (setq ghostel-module-directory
        (expand-file-name "ghostel/" user-emacs-directory)
        ghostel-module-auto-install nil))

(use-package evil-ghostel
  :after (ghostel evil)
  :hook (ghostel-mode . evil-ghostel-mode))

(defvar ghostel-compile-buffer-name)
(use-package ghostel-compile
  :commands (ghostel-compile ghostel-recompile))

(use-package term-sessions-core
  :defer t
  :init (setq term-sessions-preferred-frontend 'ghostel))
(use-package term-sessions-frontends
  :commands term-sessions-open)
(use-package term-sessions-list
  :commands term-sessions-list)
(use-package term-sessions-zmx
  :commands term-sessions-history)
(use-package term-sessions-org
  :commands term-sessions-store-org-link)
(use-package term-sessions-actions
  :commands term-sessions-action-send-text-to-session)

(defun my/term-sessions-send-text (text)
  "Select a named terminal session and send TEXT followed by Return."
  (term-sessions-action-send-text-to-session (concat text "\r")))

(defun my/term-sessions-send-region-or-buffer ()
  "Send the active region, or the full buffer, to a named terminal session."
  (interactive)
  (my/term-sessions-send-text
   (if (use-region-p)
       (buffer-substring-no-properties (region-beginning) (region-end))
     (buffer-substring-no-properties (point-min) (point-max)))))

(defvar my/annotations nil
  "Queued source annotations awaiting terminal-session delivery.")

(defun my/annotate-region (begin end annotation)
  "Queue the region from BEGIN to END with ANNOTATION."
  (interactive
   (if (use-region-p)
       (list (region-beginning) (region-end)
             (read-string "Annotation: "))
     (user-error "Select a region to annotate")))
  (push (list :source (or buffer-file-name (buffer-name))
              :start-line (line-number-at-pos begin)
              :end-line (line-number-at-pos (max begin (1- end)))
              :mode major-mode
              :annotation annotation
              :text (buffer-substring-no-properties begin end))
        my/annotations)
  (message "Queued annotation %d" (length my/annotations)))

(defun my/annotate-send-all (request)
  "Send queued annotations with optional overall REQUEST."
  (interactive (list (read-string "Overall request (optional): ")))
  (unless my/annotations
    (user-error "No annotations are queued"))
  (let ((prompt "# Review annotations\n"))
    (unless (string-empty-p request)
      (setq prompt (concat prompt "\n## Overall request\n\n" request "\n")))
    (dolist (item (reverse my/annotations))
      (setq prompt
            (concat prompt
                    "\n## " (plist-get item :source)
                    ":" (number-to-string (plist-get item :start-line))
                    "-" (number-to-string (plist-get item :end-line))
                    " (" (symbol-name (plist-get item :mode)) ")\n\n"
                    (plist-get item :annotation) "\n\n```\n"
                    (plist-get item :text) "\n```\n")))
    (my/term-sessions-send-text prompt)
    (setq my/annotations nil)))

(defun my/gptel-compose-region (begin end)
  "Open a new Gptel conversation composed from the region BEGIN to END."
  (interactive "r")
  (unless (use-region-p)
    (user-error "Select a region to compose"))
  (let ((prompt
         (format "Source: %s\nLines: %d-%d\nMode: %s\n\n```\n%s\n```\n\nRequest:\n"
                 (or buffer-file-name (buffer-name))
                 (line-number-at-pos begin)
                 (line-number-at-pos (max begin (1- end)))
                 major-mode
                 (buffer-substring-no-properties begin end))))
    (gptel (generate-new-buffer-name "*gptel-region*") nil prompt t)))

(defvar my/project-commands nil
  "Project-local alist of task labels and shell commands.
Define at least `Compile' and `Test' in the project's .dir-locals.el.")

(put 'my/project-commands 'safe-local-variable
     (lambda (value)
       (and (listp value)
            (seq-every-p
             (lambda (entry)
               (and (consp entry)
                    (stringp (car entry))
                    (stringp (cdr entry))
                    (not (string-empty-p (car entry)))
                    (not (string-empty-p (cdr entry)))))
             value))))

(defun my/project-run-command ()
  "Select and run a catalogued task at the current project root."
  (interactive)
  (let* ((project (project-current t))
         (root (project-root project))
         labels)
    (unless (funcall (get 'my/project-commands 'safe-local-variable)
                     my/project-commands)
      (user-error "Project catalog must contain nonempty string pairs"))
    (setq labels (mapcar #'car my/project-commands))
    (unless (and (assoc "Compile" my/project-commands)
                 (assoc "Test" my/project-commands))
      (user-error "Project catalog must define Compile and Test"))
    (when (not (= (length labels) (length (delete-dups (copy-sequence labels)))))
      (user-error "Project catalog contains duplicate task labels"))
    (let* ((catalog
            (append
             (list (assoc "Compile" my/project-commands)
                   (assoc "Test" my/project-commands)
                   (or (assoc "Check" my/project-commands)
                       '("Check" . "./run.py check"))
                   (or (assoc "Fix" my/project-commands)
                       '("Fix" . "./run.py check --fix")))
             (seq-remove
              (lambda (entry)
                (member (car entry) '("Compile" "Test" "Check" "Fix")))
              my/project-commands)))
           (table
            (completion-table-with-metadata
             catalog '((display-sort-function . identity)
                       (cycle-sort-function . identity))))
           (label (completing-read "Project task: " table nil t
                                   nil nil "Compile"))
           (command (cdr (assoc label catalog)))
           (default-directory root)
           (compile-command command)
           (ghostel-compile-buffer-name
            (format "*ghostel-compile: %s %s*" (project-name project) label)))
      (ghostel-compile command))))

;; language services
(use-package yasnippet
  :commands yas-minor-mode
  :config
  ;; Eglot enables Yasnippet only when it expands a server-provided snippet.
  ;; Idle TAB remains available to the major mode for ordinary indentation.
  (keymap-unset yas-minor-mode-map "TAB")
  (keymap-unset yas-minor-mode-map "<tab>")
  (keymap-unset yas-minor-mode-map "S-TAB")
  (keymap-set yas-keymap "S-TAB"
              (yas-filtered-definition 'yas-prev-field))
  (add-hook 'yas-keymap-disable-hook
            (lambda () completion-in-region-mode)))

(use-package eglot
  :commands (eglot
             eglot-code-actions
             eglot-find-declaration
             eglot-find-implementation
             eglot-find-typeDefinition
             eglot-format
             eglot-inlay-hints-mode
             eglot-rename
             eglot-show-call-hierarchy)
  :config
  ;; Install clangd, rust-analyzer, lua-language-server, ty,
  ;; typescript-language-server, zls, nimlangserver, and ols outside Emacs.
  ;; A TRAMP project requires its server executable on the remote host PATH.
  ;; Emacs 31 already knows the contract servers for C, C++, Rust, Lua,
  ;; JavaScript, TypeScript, Zig, and Odin.  Prefer ty for Python because
  ;; Eglot manages one server per buffer.  Ruff can replace ty explicitly,
  ;; but it is not started as a concurrent second server.
  (setf (alist-get '(python-mode python-ts-mode)
                   eglot-server-programs nil nil #'equal)
        '("ty" "server"))
  (add-to-list 'eglot-server-programs '(nim-mode . ("nimlangserver")))

  ;; These aliases exist only in an active Eglot buffer.  The owned leader
  ;; hierarchy is rebuilt separately in Phase 5.
  (keymap-set eglot-mode-map "C-c e f" #'eglot-format)
  (keymap-set eglot-mode-map "C-c e a" #'eglot-code-actions)
  (keymap-set eglot-mode-map "C-c e r" #'eglot-rename)
  (keymap-set eglot-mode-map "C-c e h" #'eldoc-doc-buffer)
  (keymap-set eglot-mode-map "C-c e d" #'xref-find-definitions)
  (keymap-set eglot-mode-map "C-c e R" #'xref-find-references)
  (keymap-set eglot-mode-map "C-c e D" #'eglot-find-declaration)
  (keymap-set eglot-mode-map "C-c e i" #'eglot-inlay-hints-mode)
  (keymap-set eglot-mode-map "C-c e t" #'eglot-find-typeDefinition))

(setq xref-search-program (if (executable-find "rg") 'ripgrep 'grep))

;; Install Dape explicitly with `install-packages.el'.  GUD remains the
;; default debugger and no Dape hook or global mode is enabled.  Invoke
;; `M-x dape', select `lldb-dap', and set `:program' to launch a local C,
;; C++, or Rust binary.  To attach, invoke `M-x dape' with
;; `lldb-dap :request "attach" :pid PID'.  Both forms work from a local or
;; TRAMP project, but lldb-dap must be on PATH on the machine where the
;; project lives.  Homebrew users can install it with `brew install llvm'.
(use-package dape
  :commands dape
  :config
  (setq dape-configs (list (assq 'lldb-dap dape-configs))))

(use-package flymake
  :commands (flymake-goto-next-error
             flymake-goto-prev-error
             flymake-show-buffer-diagnostics
             flymake-show-project-diagnostics))

;; languages
(use-package nim-mode
  :mode "\\.nim\\'")
(use-package odin-mode
  :mode ("\\.odin\\'" . odin-mode))
(use-package php-mode
  :mode ("\\.php\\'" . php-mode)
  :hook (php-mode . (lambda () (setq-local php-indent-offset 2))))
(use-package zig-mode
  :mode "\\.zig\\'")

(use-package markdown-mode
  :mode ("README\\.md\\'" . gfm-mode)
  :init (setq markdown-command "multimarkdown"))


;; completion
(require 'icomplete)
(setq completion-styles '(basic partial-completion flex)
      completion-category-defaults nil
      completion-category-overrides nil
      icomplete-in-buffer t
      icomplete-vertical-in-buffer-adjust-list t)
(icomplete-vertical-mode 1)

(keymap-set completion-in-region-mode-map
            "TAB" #'icomplete-forward-completions)
(keymap-set completion-in-region-mode-map
            "S-TAB" #'icomplete-backward-completions)
(keymap-set completion-in-region-mode-map
            "<backtab>" #'icomplete-backward-completions)
(advice-add 'completion-at-point :after #'minibuffer-hide-completions)

(global-completion-preview-mode -1)
(define-key evil-insert-state-map (kbd "C-SPC") #'completion-at-point)
(define-key evil-insert-state-map (kbd "C-M-i") #'completion-at-point)
(define-key evil-insert-state-map (kbd "M-/") #'dabbrev-expand)
(evil-define-key '(normal visual insert) 'global
  (kbd "C-s") #'isearch-forward)

(require 'savehist)
(add-to-list 'savehist-additional-variables 'search-ring)
(add-to-list 'savehist-additional-variables 'regexp-search-ring)
(savehist-mode 1)
(recentf-mode 1)

;; Install the pinned native grammars separately with
;; `emacs --batch -Q -l ~/.config/emacs/install-tree-sitter-grammars.el'.
(require 'treesit)
(setopt treesit-auto-install-grammar 'never
        treesit-enabled-modes
        '(c-ts-mode
          c++-ts-mode
          rust-ts-mode
          lua-ts-mode
          python-ts-mode
          js-ts-mode
          typescript-ts-mode
          tsx-ts-mode))
(setopt which-func-modes
        '(c-ts-mode
          c++-ts-mode
          rust-ts-mode
          lua-ts-mode
          python-ts-mode
          js-ts-mode
          typescript-ts-mode
          tsx-ts-mode
          markdown-ts-mode
          zig-mode
          nim-mode
          odin-mode))

(defun my/parser-tools-mode ()
  "Enable native folding and function context in parser-backed buffers."
  (let ((parser-settings
         (pcase major-mode
           ('zig-mode '(zig "function_declaration" "block"))
           ('nim-mode
            '(nim
              "\\(converter\\|func\\|iterator\\|macro\\|method\\|proc\\|template\\)_declaration"
              "\\(converter\\|func\\|iterator\\|macro\\|method\\|proc\\|template\\)_declaration"))
           ('odin-mode '(odin "procedure_declaration" "block")))))
    (when (and parser-settings
               (treesit-ready-p (car parser-settings) t))
      (let ((language (car parser-settings))
            (defun-regexp (cadr parser-settings))
            (block-regexp (caddr parser-settings)))
        (treesit-parser-create language)
        (setq-local treesit-defun-type-regexp defun-regexp
                    treesit-thing-settings
                    `((,language
                       (defun ,defun-regexp)
                       (list ,block-regexp)))
                    treesit-defun-name-function
                    (lambda (node)
                      (when (string-match-p defun-regexp
                                            (treesit-node-type node))
                        (let ((name
                               (or (treesit-node-child-by-field-name node "name")
                                   (treesit-node-child node 0 t))))
                          (when name
                            (treesit-node-text name t)))))
                    beginning-of-defun-function #'treesit-beginning-of-defun
                    end-of-defun-function #'treesit-end-of-defun
                    add-log-current-defun-function
                    #'treesit-add-log-current-defun)))
    (when (treesit-parser-list)
      (when (eq major-mode 'markdown-ts-mode)
        (setq-local treesit-thing-settings '((markdown (list "section")))))
      (when (or parser-settings (eq major-mode 'markdown-ts-mode))
        (setq-local hs-treesit-things 'list
                    hs-c-start-regexp nil
                    hs-block-start-regexp nil
                    hs-block-end-regexp
                    (unless (memq major-mode '(nim-mode markdown-ts-mode))
                      #'treesit-hs-block-end)
                    hs-forward-sexp-function #'treesit-forward-list
                    hs-find-block-beginning-function
                    #'treesit-hs-find-block-beginning
                    hs-find-next-block-function #'treesit-hs-find-next-block
                    hs-looking-at-block-start-predicate
                    #'treesit-hs-looking-at-block-start-p
                    hs-inside-comment-predicate
                    #'treesit-hs-inside-comment-p))
      (hs-minor-mode 1)
      (unless which-function-mode
        (which-function-mode 1))
      (when (or treesit-defun-type-regexp
                (treesit-thing-defined-p 'defun nil))
        (dolist (state '(normal visual operator))
          (evil-local-set-key state (kbd "[m") #'evil-backward-section-begin)
          (evil-local-set-key state (kbd "]m") #'evil-forward-section-begin)
          (evil-local-set-key state (kbd "[M") #'evil-backward-section-end)
          (evil-local-set-key state (kbd "]M") #'evil-forward-section-end))))))

(dolist (hook '(c-ts-mode-hook
                c++-ts-mode-hook
                rust-ts-mode-hook
                lua-ts-mode-hook
                python-ts-mode-hook
                js-ts-mode-hook
                typescript-ts-mode-hook
                tsx-ts-mode-hook
                markdown-ts-mode-hook
                zig-mode-hook
                nim-mode-hook
                odin-mode-hook))
  (add-hook hook #'my/parser-tools-mode))
(add-to-list
 'auto-mode-alist
 `("\\.md\\'" .
   ,(lambda ()
      (if (treesit-ready-p '(markdown markdown-inline) t)
          (progn
            (require 'markdown-ts-mode)
            (markdown-ts-mode))
        (if (string-equal (file-name-nondirectory buffer-file-name)
                          "README.md")
            (gfm-mode)
          (markdown-mode))))))


(use-package flyspell
  :hook ((prog-mode . flyspell-prog-mode)
         (text-mode . flyspell-mode))
  :config
  (setq flyspell-prog-text-faces
      (delq 'font-lock-string-face
             flyspell-prog-text-faces))
)
(use-package git-commit
  :hook (git-commit-setup . git-commit-setup-flyspell))

;; ui
(add-to-list
 'custom-theme-load-path
 (expand-file-name "themes" (file-name-directory (or load-file-name user-init-file))))
(load-theme 'mig-one-light t)

(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :config
  (setq doom-modeline-icon t)
  (setq doom-modeline-major-mode-color-icon t)
  (setq doom-modeline-minor-modes t)
)

(use-package olivetti
  :commands olivetti-mode
  :init (setq olivetti-body-width .67))
(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 1)
)

(use-package tab-bar
    :config
    (global-set-key (kbd "s-}") 'tab-bar-switch-to-next-tab)
    (global-set-key (kbd "s-{") 'tab-bar-switch-to-prev-tab)

    (setq tab-bar-select-tab-modifiers 'super)
    (global-set-key (kbd "s-t") 'tab-bar-new-tab)
    (global-set-key (kbd "s-w") 'tab-bar-close-tab)

    (setq tab-bar-tab-hints t)
)
; M-x nerd-icons-install-fonts

;; keybindings
(defun my/project-find-regexp-at-point ()
  "Search the current project for the symbol at point."
  (interactive)
  (let ((symbol (thing-at-point 'symbol t)))
    (if symbol
        (project-find-regexp (regexp-quote symbol))
      (user-error "No symbol at point"))))

(defvar my/leader-map (make-sparse-keymap)
  "Leader map shared by Evil normal and visual states.")

(dolist (prefix '("a" "b" "c" "d" "f" "g" "h" "o" "r" "s" "t" "w" "w t"))
  (keymap-set my/leader-map prefix (make-sparse-keymap)))

(dolist
    (binding
     '(("," . switch-to-buffer)
       ("/" . occur)
       ("m" . evil-show-marks)
       ("j" . evil-show-jumps)
       ("f f" . project-find-file)
       ("f o" . recentf-open-files)
       ("b b" . switch-to-buffer)
       ("w h" . evil-window-left)
       ("w j" . evil-window-down)
       ("w k" . evil-window-up)
       ("w l" . evil-window-right)
       ("w q" . delete-window)
       ("w x" . window-swap-states)
       ("w =" . balance-windows)
       ("w |" . maximize-window)
       ("w z" . delete-other-windows)
       ("w u" . winner-undo)
       ("w r" . winner-redo)
       ("w t c" . tab-bar-new-tab)
       ("w t q" . tab-bar-close-tab)
       ("w t [" . tab-bar-switch-to-prev-tab)
       ("w t ]" . tab-bar-switch-to-next-tab)
       ("s l" . occur)
       ("s g" . project-find-regexp)
       ("s w" . my/project-find-regexp-at-point)
       ("s s" . imenu)
       ("s S" . xref-find-apropos)
       ("s d" . xref-find-definitions)
       ("s D" . eglot-find-declaration)
       ("s r" . xref-find-references)
       ("s i" . eglot-find-implementation)
       ("s t" . eglot-find-typeDefinition)
       ("s I" . eglot-show-call-hierarchy)
       ("s b" . multi-occur)
       ("s H" . describe-face)
       ("s m" . evil-show-marks)
       ("s j" . evil-show-jumps)
       ("c f" . eglot-format)
       ("c r" . eglot-rename)
       ("c a" . eglot-code-actions)
       ("c h" . eldoc-doc-buffer)
       ("c i" . eglot-inlay-hints-mode)
       ("d p" . flymake-goto-prev-error)
       ("d n" . flymake-goto-next-error)
       ("d f" . flymake-show-buffer-diagnostics)
       ("d l" . flymake-show-project-diagnostics)
       ("d D" . dape)
       ("g g" . magit-status)
       ("a s" . gptel-send)
       ("t p" . ghostel-project)
       ("t t" . term-sessions-open)
       ("t l" . term-sessions-list)
       ("t h" . term-sessions-history)
       ("t o" . term-sessions-store-org-link)
       ("t c" . my/project-run-command)
       ("t r" . my/term-sessions-send-region-or-buffer)
       ("r s" . my/annotate-send-all)
       ("o a" . org-agenda)
       ("o c" . org-capture)
       ("o n" . org-roam-node-find)
       ("o i" . org-roam-node-insert)
       ("o t" . org-set-tags-command)
       ("o r" . org-table-recalculate-buffer-tables)
       ("o RET" . org-babel-execute-src-block)
       ("h o" . customize)
       ("h h" . info)
       ("h m" . man)
       ("h f" . describe-function)
       ("h v" . describe-variable)
       ("h c" . describe-command)
       ("h k" . describe-key)
       ("h l" . display-line-numbers-mode)))
  (keymap-set my/leader-map (car binding) (cdr binding)))

(defvar my/normal-leader-map (make-sparse-keymap)
  "Leader map for Evil normal state.")
(defvar my/normal-ai-map (make-sparse-keymap)
  "AI leader map for Evil normal state.")
(defvar my/visual-leader-map (make-sparse-keymap)
  "Leader map for Evil visual state.")
(defvar my/visual-ai-map (make-sparse-keymap)
  "AI leader map for Evil visual state.")
(defvar my/visual-review-map (make-sparse-keymap)
  "Review leader map for Evil visual state.")

(set-keymap-parent my/normal-leader-map my/leader-map)
(set-keymap-parent my/normal-ai-map (keymap-lookup my/leader-map "a"))
(keymap-set my/normal-ai-map "c" #'gptel)
(keymap-set my/normal-leader-map "a" my/normal-ai-map)
(set-keymap-parent my/visual-leader-map my/leader-map)
(set-keymap-parent my/visual-ai-map (keymap-lookup my/leader-map "a"))
(keymap-set my/visual-ai-map "c" #'my/gptel-compose-region)
(keymap-set my/visual-ai-map "r" #'gptel-rewrite)
(keymap-set my/visual-leader-map "a" my/visual-ai-map)
(set-keymap-parent my/visual-review-map (keymap-lookup my/leader-map "r"))
(keymap-set my/visual-review-map "a" #'my/annotate-region)
(keymap-set my/visual-leader-map "r" my/visual-review-map)
(evil-define-key 'normal 'global (kbd "SPC") my/normal-leader-map)
(evil-define-key 'visual 'global (kbd "SPC") my/visual-leader-map)

(evil-define-key '(normal visual) 'global
  (kbd "C-p") #'project-find-file)
(evil-define-key 'visual 'global
  (kbd "C-c C-c") #'my/term-sessions-send-region-or-buffer)

(with-eval-after-load 'which-key
  (which-key-add-keymap-based-replacements
    my/normal-leader-map "a" (cons "ai" my/normal-ai-map))
  (which-key-add-keymap-based-replacements
    my/visual-leader-map "a" (cons "ai" my/visual-ai-map))
  (which-key-add-keymap-based-replacements
    my/visual-leader-map "r" (cons "review" my/visual-review-map))
  (which-key-add-keymap-based-replacements
    my/leader-map
    "a" "ai"
    "b" "buffers"
    "c" "code"
    "d" "diagnostics"
    "f" "files"
    "g" "git"
    "h" "help"
    "o" "org"
    "r" "review"
    "s" "search"
    "t" "terminals"
    "w" "windows"
    "w t" "tabs"))

(require 'tramp)

(tramp-set-completion-function "ssh"
  '((tramp-parse-sconfig "/etc/ssh_config")
    (tramp-parse-sconfig "~/.ssh/config")))

(setq tramp-message-show-message nil)
(add-to-list 'tramp-remote-path 'tramp-own-remote-path)

;; https://coredumped.dev/2025/06/18/making-tramp-go-brrrr./
(setq remote-file-name-inhibit-locks t
      tramp-use-scp-direct-remote-copying t
      remote-file-name-inhibit-auto-save-visited t)

(setq tramp-copy-size-limit (* 1024 1024) ;; 1MB
      tramp-verbose 2)

(add-to-list 'tramp-connection-properties
  (list (regexp-quote "/sshx:aws-login1:")
        "remote-shell" "/bin/bash"))

(connection-local-set-profile-variables
 'remote-direct-async-process
 '((tramp-direct-async-process . t)))

(connection-local-set-profiles
 '(:application tramp :protocol "scp")
 'remote-direct-async-process)

(with-eval-after-load 'tramp
  (with-eval-after-load 'compile
    (remove-hook 'compilation-mode-hook #'tramp-compile-disable-ssh-controlmaster-options)))

(setq magit-tramp-pipe-stty-settings 'pty)

(setq ob-async-inject-variables "\\borg-babel.+")
(add-hook 'ob-async-pre-execute-src-block-hook
        (lambda ()
           ;; tramp config for async emacs process
           (setq tramp-completion-reread-directory-timeout nil)
           (setq tramp-default-method "sshx")
           (setq tramp-use-connection-share nil))
)

;; Speed up TRAMP
(setq tramp-auto-save-directory "~/tmp/tramp-autosave")
(setq tramp-chunksize 2000)

;; iterate over all bindings
(setq ispell-program-name "aspell")
(setq ispell-dictionary "english")

;; line numbers
(column-number-mode)
(global-display-line-numbers-mode 0)
(setq display-line-numbers-type 'visual)

;; disbaled in these modes
(dolist (mode '(term-mode-hook
		shell-mode-hook
		eshell-mode-hook
		ghostel-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

(setq-default indent-tabs-mode nil)  ;; no tabs



(defun copy-current-file-path ()
  "Copy the full path of the current buffer's file to the kill ring."
  (interactive)
  (let ((file-path (buffer-file-name)))
    (if file-path
        (progn
          (kill-new file-path)
          (message "Copied file path: %s" file-path))
      (message "Current buffer is not associated with a file."))))

(defun my/refile-to-journal () (interactive)
       (save-excursion
         (org-refile-to-datetree "~/org/journal.org")
       )
)

(defun my/soft-reload () (interactive)
  (load config-path)
)
(defvar my/default-font-size 13)
(defvar my/default-variable-font-size 13)
(setq my/default-font-size 13.5)
(setq my/default-variable-font-size 13.5)

(set-face-attribute 'default nil
  :font (font-spec :family "JetBrains Mono"
                   :size my/default-font-size
                   :fallback '("Apple Color Emoji"
                              "Apple Symbols"
                              "Menlo")))
;; Use 'prepend for the NS and Mac ports or Emacs will crash.
(set-fontset-font t 'unicode (font-spec :family "all-the-icons") nil 'append)
(set-fontset-font t 'unicode (font-spec :family "file-icons") nil 'append)
(set-fontset-font t 'unicode (font-spec :family "Material Icons") nil 'append)
(set-fontset-font t 'unicode (font-spec :family "github-octicons") nil 'append)
(set-fontset-font t 'unicode (font-spec :family "FontAwesome") nil 'append)
(set-fontset-font t 'unicode (font-spec :family "Weather Icons") nil 'append)

(show-paren-mode 1)
(tool-bar-mode -1)          ; Disable the toolbar
(scroll-bar-mode -1)        ; Disable visible scrollbar
(set-fringe-mode 10)        ; Give some breathing room
(menu-bar-mode -1)          ; Disable the menu bar
(blink-cursor-mode 0)
(setq ring-bell-function 'ignore)
(winner-mode 1)

(setq mac-control-modifier 'control)
(setq mac-option-modifier 'meta)
(setq mac-command-modifier 'super)
(global-set-key [kp-delete] 'delete-word) ;; sets alt-delete to be right-delete

(setq visual-line-fringe-indicators '(left-curly-arrow right-curly-arrow))


(defun my/increase-font-size () (interactive)
   (text-scale-adjust 0.5)
)

(defun my/decrease-font-size () (interactive)
   (text-scale-adjust -0.5)
)

(defun my/reset-font-size () (interactive)
   (text-scale-adjust 0)
)


(defun my/write-mode() (interactive)
   (setq olivetti-body-width 60)
   (olivetti-mode 1)
   (text-scale-set 3.0)
   (display-line-numbers-mode 0)
)

(defun my/write-mode-no-zoom() (interactive)
   (setq olivetti-body-width 120)
   (olivetti-mode 1)
   (text-scale-set 0.0)
   (display-line-numbers-mode 0)
)

(defun my/default-mode() (interactive)
   (olivetti-mode 0)
   (text-scale-set 0.0)
   (display-line-numbers-mode 1)
)
(defun my/center-window() (interactive) (olivetti-mode 1))


(with-eval-after-load 'which-key
    (global-set-key (kbd "C-=") 'my/increase-font-size)
    (global-set-key (kbd "C--") 'my/decrease-font-size)
    (global-set-key (kbd "C-0") 'my/reset-font-size)
    (global-set-key (kbd "C-x C") (lambda () (interactive) (find-file "~/.config/emacs/init.el")))
    (global-set-key (kbd "C-x R") (lambda () (interactive) (my/soft-reload)))
    (global-set-key (kbd "C-c C-c") 'eval-region)

    (global-set-key (kbd "s-1") (lambda () (interactive) (tab-select 1)))
    (global-set-key (kbd "s-2") (lambda () (interactive) (tab-select 2)))
    (global-set-key (kbd "s-3") (lambda () (interactive) (tab-select 3)))
    (global-set-key (kbd "s-4") (lambda () (interactive) (tab-select 4)))
    (global-set-key (kbd "s-5") (lambda () (interactive) (tab-select 5)))
    (global-set-key (kbd "s-6") (lambda () (interactive) (tab-select 6)))
    (global-set-key (kbd "s-7") (lambda () (interactive) (tab-select 7)))
    (global-set-key (kbd "s-8") (lambda () (interactive) (tab-select 8)))
    (global-set-key (kbd "s-9") (lambda () (interactive) (tab-select 9)))
)

;; editing basics
(defun my/cut () (interactive)
    (cond
          ((region-active-p) (kill-region (region-beginning) (region-end)))
          ('t (kill-whole-line))
    )
)

(defun my/copy () (interactive)
    (cond
          ((region-active-p) (kill-ring-save (region-beginning) (region-end)))
          ('t (kill-ring-save (line-beginning-position)
                              (line-beginning-position 2)))
    )
)

(defun region-to-some-buffer (beg end)
  (interactive "r")
  (let ((input (buffer-substring beg end))
        (new-buffer (get-buffer-create "*my-buffer*")))
    (pop-to-buffer new-buffer)
    (fundamental-mode)  ;; replace with desired mod
    (insert input)))

(defun org-copy-to-datetree (&optional file)
  "Refile a subtree to a datetree corresponding to it's timestamp.

The current time is used if the entry has no timestamp. If FILE
is nil, refile in the current file."
  (interactive "f")
  (let* ((datetree-date (or (org-entry-get nil "TIMESTAMP" t)
                            (org-read-date t nil "now")))
         (date (org-date-to-gregorian datetree-date))
         )
    (with-current-buffer (current-buffer)
      (save-excursion
        (org-copy-subtree)
        (if file (find-file file))
        (org-datetree-find-date-create date)
        (org-narrow-to-subtree)
        (outline-show-subtree)
        (org-end-of-subtree t)
        (newline)
        (goto-char (point-max))
        (org-paste-subtree 4)
        (widen)
        ))
    )
)
;; https://emacs.stackexchange.com/questions/10597/how-to-refile-into-a-datetree
(defun org-refile-to-datetree (&optional file)
  "Refile a subtree to a datetree corresponding to it's timestamp.

The current time is used if the entry has no timestamp. If FILE
is nil, refile in the current file."
  (interactive "f")
  (let* ((datetree-date (or (org-entry-get nil "TIMESTAMP" t)
                            (org-read-date t nil "now")))
         (date (org-date-to-gregorian datetree-date))
         )
    (with-current-buffer (current-buffer)
      (save-excursion
        (org-cut-subtree)
        (if file (find-file file))
        (org-datetree-find-date-create date)
        (org-narrow-to-subtree)
        (outline-show-subtree)
        (org-end-of-subtree t)
        (newline)
        (goto-char (point-max))
        (org-paste-subtree 4)
        (widen)
        ))
    )
)

(global-set-key (kbd "s-c") 'my/copy)
(global-set-key (kbd "s-x") 'my/cut)
(global-set-key (kbd "s-v") 'yank)
(global-set-key (kbd "s-s") 'save-buffer)

;; TODO: styling
(setq c-default-style "bsd" c-basic-offset 4)

(setq indent-tabs-mode nil)

(require 'org-autolist "~/.config/emacs/better-ret.el")
(add-hook 'org-mode-hook (lambda () (org-autolist-mode)))

(setq-default indent-tabs-mode nil)  ; Use spaces instead of tabs
(setq-default tab-width 2)           ; Set tab width to 2
(setq-default standard-indent 2)     ; Set standard indent to 2

(setq-default lisp-indent-offset 2)  ; lisp
(setq-default c-basic-offset 4)      ; C/C++/Java
(setq-default js-indent-level 2)     ; JavaScript
(setq-default css-indent-offset 2)   ; CSS
(setq-default sgml-basic-offset 2)   ; HTML
(setq-default python-indent-offset 4) ; Python
