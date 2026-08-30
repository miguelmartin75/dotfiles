;; SECTION: fundamental  -*- lexical-binding: t; -*-
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
 '(tramp-use-ssh-controlmaster-options nil)
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

(use-package websocket)
(use-package simple-httpd)
;;(use-package org-super-agenda)
;;(use-package org-ql)
;; (use-package org-ql)


(setq config-path "~/.config/emacs/init.el")
;; (load "~/.config/emacs/defaults.el")

(electric-indent-mode)

;; (defun my/remove-datetree-day-heading ()
;;   "Remove the intermediate day-level heading under a weekly capture."
;;   (save-excursion
;;     (goto-char (point-min))
;;     ;; Look for the day heading ("*** YYYY-MM-DD Weekday")
;;     (when (re-search-forward "^\\*\\*\\* [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} .*$" nil t)
;;       (let ((beg (line-beginning-position))
;;             (end (progn (forward-line 1) (point))))
;;         (delete-region beg end)))))



(use-package magit)
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

  (defun my/org-summary-todo (n‑done n‑not‑done)
    "Set parent to DONE if all children are done, TODO if none, DOING otherwise."
    (let (org-log-done org-log-states)  ;; suppress change logging
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



  ;;(add-hook 'org-after-todo-state-change-hook (lambda ()
  ;;   (when
  ;;     (string= org-state "DONE")
  ;;     (org-refile-to-datetree "~/org/journal.org")
  ;;   )
  ;;))

)

(require 'org-tempo)

(use-package org-fragtog
    :config
    (add-hook 'org-mode-hook 'org-fragtog-mode)
    (setq org-odt-pixels-per-inch 192.0)
    (setq org-latex-create-formula-image-program 'dvisvgm)
    (setq org-format-latex-options '(:foreground default :background default :scale 2.5 :html-foreground "Black" :html-background "Transparent" :html-scale 1.0 :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
)

;; AI
(use-package gptel
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
(use-package inline-diff
  :after gptel-rewrite) ;or use :defer

(use-package org-roam
      :hook
      (after-init . org-roam-mode)
      :custom
      ;; (org-roam-directory (file-truename "~/org/roam"))
      (org-roam-directory (file-truename "~/org/"))
      (setq org-roam-db-location "~/.org-roam.db")
      :config
      ;; (setq org-roam-v2-ack t)
      (add-hook 'org-roam-hook (org-roam-db-autosync-mode))
      (setq org-roam-display-template (concat "${title:*} " (propertize "${tags:*}" 'face 'org-tag)))
)

;;(use-package org-roam-ui
;;    :after org-roam
;;;;         normally we'd recommend hooking orui after org-roam, but since org-roam does not have
;;;;         a hookable mode anymore, you're advised to pick something yourself
;;;;         if you don't care about startup time, use
;;;;  :hook (after-init . org-roam-ui-mode)
;;    :config
;;    (setq org-roam-ui-sync-theme t
;;          org-roam-ui-follow t
;;          org-roam-ui-update-on-save t
;;          org-roam-ui-open-on-start t))
(use-package command-log-mode)

;; research
(use-package bibtex-completion)

(use-package org-roam-bibtex
  :after org-roam
  :requires bibtex-completion
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

(use-package org-ref
  :commands (org-ref-insert-cite-link
             org-ref-open-pdf-at-point
             org-ref-open-url-at-point))
(use-package gscholar-bibtex)


;; TODO: fix this up

(use-package ob-async)
;;(setq ob-async-no-async-languages-alist '("ipython"))
;;(use-package org-datetree)

;; evil
(use-package undo-tree :init (global-undo-tree-mode))

(use-package evil
   :after undo-tree
   :init
   (setq evil-want-integration t)
   (setq evil-want-keybinding nil)
   (setq evil-want-C-u-scroll t)
   (setq evil-want-C-i-jump t)
   (setq evil-want-C-w-delete t)
   (setq evil-want-C-w-in-emacs-state t)
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
   ;; Use visual line motions even outside of visual-line-mode buffers
   ;;(evil-global-set-key 'motion "j" 'evil-next-visual-line)
   ;;(evil-global-set-key 'motion "k" 'evil-previous-visual-line)
   ;;(evil-global-set-key 'insert "C-w" 'evil-delete-backward-word)
   ;;(evil-global-set-key 'insert "A-DEL" 'evil-delete-backward-word)
   ;;(evil-global-set-key 'insert "M-DEL" 'evil-delete-whole-line)

   (evil-set-initial-state 'messages-buffer-mode 'normal)
   (evil-set-initial-state 'dashboard-mode 'normal)
   (evil-set-initial-state 'vterm-mode 'insert)

   (setq evil-search-module 'evil-search)
   (evil-select-search-module 'evil-search-module 'evil-search)

   ;; minor mode
   (add-hook 'org-capture-mode-hook 'evil-insert-state)

   (setq evil-undo-system 'undo-tree)

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

;; TODO removeme
;; (use-package vi-tilde-fringe
;;   :config
;;   (global-vi-tilde-fringe-mode 1))

(use-package
  evil-numbers
  :config
  (evil-define-key '(normal visual) 'global (kbd "C-c +") 'evil-numbers/inc-at-pt)
  (evil-define-key '(normal visual) 'global (kbd "C-c -") 'evil-numbers/dec-at-pt)
)

;; TODO move me
(global-undo-tree-mode)
(evil-set-undo-system 'undo-tree)
(setq undo-tree-history-directory-alist '(("." . "~/.config/emacs/undo")))

;; terminal
(use-package vterm
  :hook (vterm-mode . compilation-shell-minor-mode)
  :config
  (setq vterm-keymap-exceptions nil)
;; TODO re-map some of these with CMD prefix
  (evil-define-key 'insert vterm-mode-map (kbd "C-e")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-f")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-a")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-v")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-b")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-w")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-u")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-d")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-n")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-m")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-p")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-j")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-k")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-r")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-t")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-g")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-c")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "C-SPC")    #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "s-<left>")  #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "s-<right>") #'vterm--self-insert)

  (evil-define-key 'normal vterm-mode-map (kbd "C-d")      #'vterm--self-insert)
  (evil-define-key 'normal vterm-mode-map (kbd "i")        #'evil-insert-resume)
  (evil-define-key 'normal vterm-mode-map (kbd "o")        #'evil-insert-resume)
  (evil-define-key 'normal vterm-mode-map (kbd "<return>") #'evil-insert-resume)
  (evil-define-key 'insert vterm-mode-map (kbd "<escape>")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "s-<escape>")    #'evil-normal-state)

  ;; (setq vterm-term-environment-variable "xterm-24bit")

  (add-hook 'vterm-mode-hook (lambda () (visual-line-mode 0)))
  (add-hook 'vterm-mode-hook (lambda () (vi-tilde-fringe-mode 0)))
)

(defun my/run-in-vterm (command)
  "Run COMMAND in a dedicated vterm buffer with compilation parsing."
  (interactive
   (list (read-shell-command "Run or Compile (vterm): "
                             compile-command)))
  (let ((buf (get-buffer-create "*vterm-compile*")))
    (with-current-buffer buf
      (unless (eq major-mode 'vterm-mode) (vterm))
      (compilation-shell-minor-mode)
      (vterm-send-string command)
      (vterm-send-return))
    (pop-to-buffer buf)))

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
  :commands eglot
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

;; languages
(use-package nim-mode)
(use-package odin-mode
  :mode ("\\.odin\\'" . odin-mode))
(use-package php-mode
  :mode ("\\.php\\'" . php-mode)
  :hook (php-mode . (lambda () (setq-local php-indent-offset 2))))
(use-package zig-mode)
(use-package swift-mode)
;; https://justinramel.github.io/2013/09/25/vim-to-emacs-smart-tab/
;; (use-package smart-tab :config (global-smart-tab-mode t) (setq smart-tab-using-hippie-expand t))

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
;; `emacs --batch -l ~/.config/emacs/install-tree-sitter-grammars.el'.
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
          markdown-ts-mode))

(defun my/parser-tools-mode ()
  "Enable native folding and function context in parser-backed buffers."
  (when (eq major-mode 'markdown-ts-mode)
    (setq-local treesit-thing-settings '((markdown (list "section")))
                hs-treesit-things 'list
                hs-c-start-regexp nil
                hs-block-start-regexp nil
                hs-block-end-regexp nil
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
    (which-function-mode 1)))

(dolist (hook '(c-ts-mode-hook
                c++-ts-mode-hook
                rust-ts-mode-hook
                lua-ts-mode-hook
                python-ts-mode-hook
                js-ts-mode-hook
                typescript-ts-mode-hook
                tsx-ts-mode-hook
                markdown-ts-mode-hook))
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


;; (flyspell-mode) this is a test on comments
(use-package flyspell
  :config
  (flyspell-prog-mode)
  ;; disable for strings:
  ;; https://emacs.stackexchange.com/questions/31300/can-you-turn-on-flyspell-for-comments-but-not-strings
  (setq flyspell-prog-text-faces
      (delq 'font-lock-string-face
             flyspell-prog-text-faces))
)

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

(use-package olivetti :init (setq olivetti-body-width .67))
(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 1)
)

(use-package helpful
  :bind
  ([remap describe-function] . helpful-callable)
  ([remap describe-command] . helpful-command)
  ([remap describe-variable] . helpful-variable)
  ([remap describe-key] . helpful-key))


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
(use-package all-the-icons :if (display-graphic-p))


;; keybindings
(use-package general
    :config
    (general-create-definer my/leader-keys
	:keymaps '(normal insert visual emacs)
	:prefix "SPC")
)

(defun my/linear-load-api-key-from-auth-source ()
  "Load Linear API key from auth-source."
  (interactive)
  (require 'auth-source)
  (let* ((auth-info (auth-source-search :host "api.linear.app" :user "apikey" :max 1))
         (secret (when auth-info
                   (funcall (plist-get (car auth-info) :secret)))))
    (if secret
        (progn
          (setq linear-emacs-api-key secret)
          (message "Successfully loaded Linear API key from auth-source"))
      (message "Failed to retrieve Linear API key from auth-source"))))

;; (use-package
;;   linear-emacs
;;   :load-path "~/emacs/linear-emacs/"
;;   :config
;;   (setq linear-emacs-org-file-path (expand-file-name "work/linear.org" org-directory))
;;   (linear-emacs-load-api-key-from-env)
;;   (setq linear-emacs-issues-state-mapping
;;         '(("Todo" . "TODO")
;;           ("In Progress" . "DOING")
;;           ("In Review" . "REVIEW")
;;           ("Blocked" . "BLOCKED")
;;           ("Done" . "DONE")))
;;
;;   (defun my/enable-linear-org-sync ()
;;     "Enable Linear-org synchronization when linear.org is opened."
;;     (when (and buffer-file-name
;;                (string-match-p "linear\\.org$" buffer-file-name))
;;       (linear-emacs-enable-org-sync)
;;       (message "Linear-org synchronization enabled for this buffer")))
;;
;;   (add-hook 'find-file-hook #'my/enable-linear-org-sync)
;;   (my/leader-keys "G"  '((lambda () (interactive) (find-file (expand-file-name "work/linear.org" org-directory)))  :which-key "goto linear file"))
;;   (my/leader-keys "gl"  '(linear-emacs-list-issues          :which-key "List Linear issues"))
;;   (my/leader-keys "gn"  '(linear-emacs-new-issue            :which-key "Create new issue"  ))
;;   (my/leader-keys "gs"  '(linear-emacs-sync-org-to-linear   :which-key "Sync current issue"))
;;   (my/leader-keys "ge"  '(linear-emacs-enable-org-sync      :which-key "Enable org sync"   ))
;;   (my/leader-keys "gd"  '(linear-emacs-disable-org-sync     :which-key "Disable org sync"  ))
;;   (my/leader-keys "gt"  '(linear-emacs-test-connection      :which-key "Test connection"   ))
;;   (my/leader-keys "gd"  '(linear-emacs-toggle-debug         :which-key "Toggle debug mode" ))
;; )

(my/leader-keys "[" '(flymake-goto-prev-error :which-key "prev error"))
(my/leader-keys "]" '(flymake-goto-next-error :which-key "next error"))
(my/leader-keys "b" '(compile :which-key "compile"))
(my/leader-keys "c" '(my/compile :which-key "compile"))
(my/leader-keys "r" '(my/run-app :which-key "run"))
;;(my/leader-keys "t" '(my/run-current-test :which-key "run current test"))
;; todo
(my/leader-keys "t" '(org-todo :which-key "change todo state"))

(my/leader-keys "Z" '(my/write-mode :which-key "zen mode"))
(my/leader-keys "z" '(my/write-mode-no-zoom :which-key "zen mode no zoom"))
(my/leader-keys "v" '(my/default-mode :which-key "code mode"))

(my/leader-keys "/" '(comment-or-uncomment-region :which-key "toggle comment"))

;; TODO fixme

(my/leader-keys "e" '(org-set-effort :which-key "set effort for org-mode"))
(my/leader-keys "x" '(org-capture :which-key "capture task"))
(my/leader-keys "n" '(org-roam-node-find :which-key "roam files"))
(my/leader-keys "j" '(my/goto-journal :which-key "goto journal"))

(my/leader-keys "oc" '(org-table-recalculate-buffer-tables :which-key "recaclc tables in buffer"))
(my/leader-keys "on" '(org-id-get-create :which-key "create node"))

(my/leader-keys "wz" '(delete-other-windows :which-key "zoom window"))
(my/leader-keys "wj" '(evil-window-down :which-key "win down"))
(my/leader-keys "wk" '(evil-window-up :which-key "win up"))
(my/leader-keys "wh" '(evil-window-left :which-key "win left"))
(my/leader-keys "wl" '(evil-window-right :which-key "win right"))
(my/leader-keys "wm" '(evil-window-right :which-key "win right"))
(my/leader-keys "wu" '(winner-undo :which-key "winner undo"))
(my/leader-keys "wr" '(winner-redo :which-key "winner redo"))
(my/leader-keys "wm" '(maximize-window :which-key "maximize window"))

(my/leader-keys "RET" '(org-babel-execute-src-block :which-key "execute org-mode source block"))
(my/leader-keys "h" '(evil-ex-nohighlight :which-key "disable current highlight"))

(my/leader-keys "f" '(org-narrow-to-subtree :which-key "narrow to subtree"))
(my/leader-keys "F" '(widen :which-key "widen narrow"))

(my/leader-keys "E" '(eglot :which-key "start eglot/LSP"))

(my/leader-keys "L" '(org-insert-link :which-key "insert link in org-mode"))
(my/leader-keys "l" '(display-line-numbers-mode :which-key "toggle line numbers"))

;; TODO: need this operation
(my/leader-keys "i" '(org-roam-node-insert :which-key "insert roam link"))
(my/leader-keys "mt" '(org-roam-tag-add :which-key "add tag"))
(my/leader-keys "mT" '(org-roam-tag-remove :which-key "remove tag"))

(my/leader-keys "k" '(describe-key :which-key "describe key"))

; gptel bindings


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
        '(lambda ()
           ;; tramp config for async emacs process
           (setq tramp-completion-reread-directory-timeout nil)
           (setq tramp-default-method "sshx")
           (setq tramp-use-ssh-controlmaster-options nil))
)

;; Speed up TRAMP
(setq tramp-auto-save-directory "~/tmp/tramp-autosave")
(setq tramp-chunksize 2000)

;; Disable version control for remote files (faster)
(setq vc-ignore-dir-regexp
      (format "\\(%s\\)\\|\\(%s\\)"
              vc-ignore-dir-regexp
              tramp-file-name-regexp))


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
		treemacs-mode-hook
		eshell-mode-hook
		vterm-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

;; (dolist (mode '(vterm-mode-hook)) (add-hook mode (lambda () (turn-off-evil-mode))))

(setq-default indent-tabs-mode nil)  ;; no tabs



;; TODO refactor this?
(setq my/current-test "test_lexer")
(defun my/build-path ()
  (concat (locate-dominating-file "." "CMakeLists.txt") "build"))
(defun my/current-test-path () () (concat (my/build-path) "/" my/current-test))
(defun my/run-current-test () (interactive)
    (async-shell-command (my/current-test-path)))

(defun my/compile ()
  (interactive)
  (let ((default-directory (my/build-path)))
    (compile "cmake --build . -j")))

(defun my/run-app ()
  (interactive)
  (let ((default-directory (my/build-path)))
    (eshell-command "ctest")))

;; https://yiming.dev/blog/2018/03/02/my-org-refile-workflow/
;; (defun org-search-heading ()
;;   (interactive)
;;   (org-refile '(4)))

;; source: http://steve.yegge.googlepages.com/my-dot-emacs-file
(defun rename-file-and-buffer (new-name)
  "Renames both current buffer and file it's visiting to NEW-NAME."
  (interactive "sNew name: ")
  (let ((name (buffer-name))
        (filename (buffer-file-name)))
    (if (not filename)
        (message "Buffer '%s' is not visiting a file!" name)
      (if (get-buffer new-name)
          (message "A buffer named '%s' already exists!" new-name)
        (progn
          (rename-file filename new-name 1)
          (rename-buffer new-name)
          (set-visited-file-name new-name)
          (set-buffer-modified-p nil))))))

(defun delete-file-and-buffer ()
  "Deletes the current buffer and file"
  (interactive)
  ;; https://gist.github.com/hyOzd/23b87e96d43bca0f0b52
  (let
      ((filename (buffer-file-name)))
    (if filename
        (if (y-or-n-p (concat "Really delete " filename " ?"))
            (progn
                (delete-file filename)
                (message "Deleted file %s" filename)
                (kill-buffer)
            )
          )
      (message "Not a file buffer: %s" filename)
      )
    )
  )

(defun copy-current-file-path ()
  "Copy the full path of the current buffer's file to the kill ring."
  (interactive)
  (let ((file-path (buffer-file-name)))
    (if file-path
        (progn
          (kill-new file-path)
          (message "Copied file path: %s" file-path))
      (message "Current buffer is not associated with a file."))))

(defun org-get-logbook-notes ()
  (save-excursion
    (unless (org-at-heading-p)
      (outline-previous-heading))
    (when (re-search-forward ":LOGBOOK:" (save-excursion
                                           (outline-next-heading)
                                           (point))
                             t)
      (let* ((elt (org-element-property-drawer-parser nil))
             (beg (org-element-property :contents-begin elt))
             (end (org-element-property :contents-end elt)))
        (buffer-substring-no-properties beg end)))))

(defun my/compute-stats-time-for-heading () (interactive)
    (save-excursion
        (unless (org-at-heading-p)
            (outline-previous-heading))
        (let* (
              (logbook (org-get-logbook-notes))
              (logbook-entries (split-string logbook "\n"))
              )
           (message (car logbook-entries))
              ;;(let prev_t (my/compute-stats-get-time (car logbook))
        )
    )
)


(defun my/refile-to-journal () (interactive)
       (save-excursion
         (org-refile-to-datetree "~/org/journal.org")
       )
)

(defun my/soft-reload () (interactive)
  (load config-path)
)
(defun my/entries-from-last-week () (interactive)
    (org-ql-search (org-agenda-files)
        '(ts :from -7 :to today)
        :title "Recent Items"
        :sort '(todo priority date)
        :super-groups '((:auto-ts t)))
)

(defun my/test-org-ql () (interactive)
    (org-ql-search "~/src/emacs/org-super-agenda/test/test.org"
        '(and (or (ts-active :on today)
                (deadline auto)
                (scheduled :to today))
            (not (done)))
        :title "My Agenda View"
        ;; The `org-super-agenda-groups' setting is used automatically when set, or it
        ;; may be overriden by specifying it here:
        :super-groups '((:name "Bills"
                            :tag "bills")
                        (:todo ("SOMEDAY" "TO-READ" "CHECK" "TO-WATCH" "WATCHING")
                            :order 7)
                        (:name "Personal"
                            :habit t
                            :tag "personal"
                            :order 3)
                        (:todo "WAITING"
                            :order 6)
                        (:priority "A" :order 1)
                        (:priority "B" :order 2)
                        (:priority "C" :order 2)))
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

(setq visual-fill-column-width 120)
(setq visual-fill-column-fringes-outside-margins nil)
(setq visual-line-fringe-indicators '(left-curly-arrow right-curly-arrow))


(defun my/increase-font-size () (interactive)
   (text-scale-adjust 0.5)
)

(defun my/decrease-font-size () (interactive)
   (text-scale-adjust -0.5)
)

(defun my/reset-font-size () (interactive)
   (text-scale-adjust)
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
      ;; TODO figure out which-key here
    (global-set-key (kbd "C-=") 'my/increase-font-size)
    (global-set-key (kbd "C--") 'my/decrease-font-size)
    (global-set-key (kbd "C-0") 'my/reset-font-size)
    ;; (global-set-key (kbd "M-x") 'execute-extended-command)
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
          ('t (evil-yank-line))
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
        (show-subtree)
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
        (show-subtree)
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
