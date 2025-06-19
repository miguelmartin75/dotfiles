;; SECTION: fundamental
(require 'package)

(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)

(unless package-archive-contents (package-refresh-contents))

;; Initialize use-package on non-Linux platforms
(unless (package-installed-p 'use-package) (package-install 'use-package))


(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(require 'use-package)
(setq use-package-always-ensure t)

(unless (package-installed-p 'quelpa)
  (with-temp-buffer
    (url-insert-file-contents "https://raw.githubusercontent.com/quelpa/quelpa/master/quelpa.el")
    (eval-buffer)
    (quelpa-self-upgrade)))

(quelpa
 '(quelpa-use-package
   :fetcher git
   :url "https://github.com/quelpa/quelpa-use-package.git"))
(require 'quelpa-use-package)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("a9eeab09d61fef94084a95f82557e147d9630fbbb82a837f971f83e66e21e5ad"
     "2ab8cb6d21d3aa5b821fa638c118892049796d693d1e6cd88cb0d3d7c3ed07fc"
     "e14289199861a5db890065fdc5f3d3c22c5bac607e0dbce7f35ce60e6b55fc52"
     "7e068da4ba88162324d9773ec066d93c447c76e9f4ae711ddd0c5d3863489c52"
     "1a1ac598737d0fcdc4dfab3af3d6f46ab2d5048b8e72bc22f50271fd6d393a00"
     "d268b67e0935b9ebc427cad88ded41e875abfcc27abd409726a92e55459e0d01"
     "1704976a1797342a1b4ea7a75bdbb3be1569f4619134341bd5a4c1cfb16abad4"
     "7a7b1d475b42c1a0b61f3b1d1225dd249ffa1abb1b7f726aec59ac7ca3bf4dae"
     "37768a79b479684b0756dec7c0fc7652082910c37d8863c35b702db3f16000f8"
     default))
 '(org-agenda-files '("/Users/miguelmartin/org/everything.org"))
 '(package-selected-packages
   '(nim-mode org-autolist which-key vterm vi-tilde-fringe use-package
              undo-tree org-ref org-fragtog olivetti nord-theme magit
              lsp-ivy ivy-rich ivy-bibtex helpful gscholar-bibtex
              general flycheck evil-org evil-collection
              evil-better-visual-line dap-mode counsel company
              command-log-mode))
 '(server-port "1492")
 '(server-use-tcp t)
 '(tramp-completion-reread-directory-timeout nil)
 '(tramp-default-method "sshx")
 '(tramp-use-ssh-controlmaster-options nil)
 '(warning-suppress-log-types '((comp))))
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
; (exec-path-from-shell-initialize)

(use-package websocket)
(use-package simple-httpd)
;;(use-package org-super-agenda)
;;(use-package org-ql)
;; (use-package org-ql
;;   :quelpa (org-ql :fetcher github :repo "alphapapa/org-ql"
;;             :files (:defaults (:exclude "helm-org-ql.el"))))



(setq config-path "~/.config/emacs/init.el")
;; (load "~/.config/emacs/defaults.el")
;; (load "~/.config/emacs/editing-basics.el")
;; (load "~/.config/emacs/org-config.el")
;; (load "~/.config/emacs/evil-config.el")
;; (load "~/.config/emacs/ui-config.el")
;; (load "~/.config/emacs/primitives.el")
;; (load "~/.config/emacs/completion-config.el")
;; (load "~/.config/emacs/work-config.el")


(use-package org :ensure t
    :config
  (setq org-todo-keywords
	'((sequence "TODO(t!)" "POST(p!)" "DOING(d!)" "BLOCKED(b!)" "|" "DONE(f!)" "CANCELED(c!@)")))
  (setq org-capture-templates
	'(
          ("r" "Reading List" (file+opt "~/org/to_read.org") "* TODO %?" :)
	  ("n" "Note" entry (file+olp+datetree "~/org/journal.org")
	   "* %T %? :note:" :empty-lines 1)
	  ("b" "Task: Backlog" entry (file+olp "~/org/life.org" "Tasks" "Backlog")
	   "* TODO %? :backlog:\n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("t" "Add Task" entry (file+olp+datetree "~/org/journal.org")
	   "* TODO %? \n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("l" "Log" entry (file+olp+datetree "~/org/journal.org")
	   "* %T %? :log:" :empty-lines 1)
	  ("B" "Task: Work Backlog" entry (file "~/org/life.org")
	   "* TODO %? :backlog:work:\n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("T" "Add Work Task" entry (file+olp+datetree "~/org/journal.org")
	   "* TODO %? :work:\n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("L" "Work Log" entry (file+olp+datetree "~/org/journal.org")
	   "* %T %? :log:work:" :empty-lines 1)
	  ("m" "Meeting" entry (file+olp+datetree "~/org/journal.org")
	   "* %T %? :meeting:work:" :empty-lines 1)
	  ("r" "Week Review" entry (file+olp+datetree "~/org/journal.org")
	   "* Week Review: %t - %(- %t 7) :review:" :empty-lines 1)
	  ("j" "Journal Entry" entry (file+olp+datetree "~/org/journal.org")
	   "* %t :journal:\n%?" :empty-lines 1)
	  ("i" "Idea" entry (file+olp "~/org/life.org" "Ideas")
	   "* %?\nAdded: %U :inbox:idea:" :empty-lines 1)
	  ))

  (setq org-src-preserve-indentation t)
  (add-hook 'org-mode-hook (lambda () (electric-indent-mode -1)))
  (add-hook 'org-mode-hook (lambda () (company-mode 0)))

  (setq org-agenda-files '("~/org/tasks.org" "~/org/life.org"))

  (setq org-log-into-drawer t)
  (setq org-tags-column 0)

  ;; don't add this
  ;;(add-hook 'org-after-todo-state-change-hook (lambda ()
  ;;   (when
  ;;     (string= org-state "DONE")
  ;;     (org-refile-to-datetree "~/org/journal.org")
  ;;   )
  ;;))
)

(require 'org-tempo) ;; templates

(use-package org-fragtog
    :ensure t
    :config
    (add-hook 'org-mode-hook 'org-fragtog-mode)
    (setq org-odt-pixels-per-inch 192.0)
    (setq org-latex-create-formula-image-program 'dvisvgm)
    (setq org-format-latex-options '(:foreground default :background default :scale 2.5 :html-foreground "Black" :html-background "Transparent" :html-scale 1.0 :matchers ("begin" "$1" "$" "$$" "\\(" "\\[")))
)

;; AI
;;
(use-package gptel
  :config
  (gptel-make-anthropic "Claude" :stream t :key gptel-api-key)
  )

;;(use-package org-roam :ensure t
;;      ;; :hook
;;      ;; (after-init . org-roam-mode)
;;      :custom
;;      ;; (org-roam-directory (file-truename "~/org/roam"))
;;      (org-roam-directory (file-truename "~/org/"))
;;      (setq org-roam-db-location "~/.org-roam.db")
;;      :config
;;      (setq org-roam-v2-ack t)
;;      (add-hook 'org-roam-hook (org-roam-db-autosync-mode))
;;      (setq org-roam-display-template (concat "${title:*} " (propertize "${tags:*}" 'face 'org-tag)))
;;)
;;
;;
;;(use-package org-roam-ui
;;  :straight
;;    (:host github :repo "org-roam/org-roam-ui" :branch "main" :files ("*.el" "out"))
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
(use-package command-log-mode :ensure t)

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

(use-package org-ref)
(use-package ivy-bibtex :config
  (ivy-add-actions 'ivy-bibtex '(("u" ivy-bibtex-open-url-or-doi "Open URL or DOI in browser")
				 ("p" ivy-bibtex-open-pdf "Open PDF file (if present)"))))
(use-package gscholar-bibtex)


;; TODO: fix this up

(use-package ob-async :ensure t)
;;(setq ob-async-no-async-languages-alist '("ipython"))
;;(use-package org-datetree)

;; evil
(use-package undo-tree :init (global-undo-tree-mode))

(use-package evil
   :after undo-tree
   :ensure t
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
  :ensure t
  :config
  (global-evil-surround-mode 1))

(use-package evil-collection
  :after evil
  :ensure t
  :config
  (evil-collection-init))

(use-package evil-org
  :ensure t
  :after org
  :init (evil-org-mode)
  :config
  (add-hook 'org-mode-hook 'evil-org-mode)
  (add-hook 'evil-org-mode-hook
	      (lambda ()
		(evil-org-set-key-theme)))
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

(use-package evil-better-visual-line
  :ensure t
  :config
  (evil-better-visual-line-on))

;; TODO removeme
;; (use-package vi-tilde-fringe
;;   :ensure t
;;   :config
;;   (global-vi-tilde-fringe-mode 1))

;; TODO
;; (use-package evil-numbers :ensure t)

;; TODO move me
(global-undo-tree-mode)
(evil-set-undo-system 'undo-tree)

;; terminal
(use-package vterm
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
  (evil-define-key 'insert vterm-mode-map (kbd "S-<left>")  #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "S-<right>") #'vterm--self-insert)

  (evil-define-key 'normal vterm-mode-map (kbd "C-d")      #'vterm--self-insert)
  (evil-define-key 'normal vterm-mode-map (kbd "i")        #'evil-insert-resume)
  (evil-define-key 'normal vterm-mode-map (kbd "o")        #'evil-insert-resume)
  (evil-define-key 'normal vterm-mode-map (kbd "<return>") #'evil-insert-resume)
  (evil-define-key 'insert vterm-mode-map (kbd "<escape>")      #'vterm--self-insert)
  (evil-define-key 'insert vterm-mode-map (kbd "S-<escape>")    #'evil-normal-state)

  (setq vterm-term-environment-variable "xterm-24bit")

  (add-hook 'vterm-mode-hook (lambda () (visual-line-mode 0)))
  (add-hook 'vterm-mode-hook (lambda () (vi-tilde-fringe-mode 0)))
)

;; -- ----------
;; lsp
(use-package eglot
  :config
  (add-to-list 'eglot-server-programs
             `(swift-mode . ("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp")))
  (add-to-list 'eglot-server-programs
             `(nim-mode . ("")))

)
;;(use-package lsp-mode
;;  :config
;;  (lsp-register-client
;;   (make-lsp-client
;;    :new-connection (lsp-stdio-connection "~/zls/zig-out/bin/zls")
;;    :major-modes '(zig-mode)
;;    :server-id 'zls
;;    :priority -1
;;    ))
;;)

;; languages
(use-package nim-mode)
(use-package zig-mode)
(use-package swift-mode)
;; https://justinramel.github.io/2013/09/25/vim-to-emacs-smart-tab/
(use-package smart-tab :config (global-smart-tab-mode t) (setq smart-tab-using-hippie-expand t))

(use-package markdown-mode
  :ensure t
  :mode ("README\\.md\\'" . gfm-mode)
  :init (setq markdown-command "multimarkdown"))


;; completion
(use-package corfu
  ;; Optional customizations
  ;; :custom
  ;; (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  ;; (corfu-quit-at-boundary nil)   ;; Never quit at completion boundary
  ;; (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  ;; (corfu-preview-current nil)    ;; Disable current candidate preview
  ;; (corfu-preselect 'prompt)      ;; Preselect the prompt
  ;; (corfu-on-exact-match nil)     ;; Configure handling of exact matches

  ;; Enable Corfu only for certain modes. See also `global-corfu-modes'.
  ;; :hook ((prog-mode . corfu-mode)
  ;;        (shell-mode . corfu-mode)
  ;;        (eshell-mode . corfu-mode))

  :init

  ;; Recommended: Enable Corfu globally.  Recommended since many modes provide
  ;; Capfs and Dabbrev can be used globally (M-/).  See also the customization
  ;; variable `global-corfu-modes' to exclude certain modes.
  (global-corfu-mode)

  ;; Enable optional extension modes:
  ;; (corfu-history-mode)
  ;; (corfu-popupinfo-mode)
)

;; Add extensions
(use-package cape
  ;; Bind dedicated completion commands
  :bind (("C-c p p" . completion-at-point) ;; capf
         ("C-c p t" . complete-tag)        ;; etags
         ("C-c p d" . cape-dabbrev)        ;; or dabbrev-completion
         ("C-c p f" . cape-file)
         ("C-c p k" . cape-keyword)
         ("C-c p s" . cape-symbol)
         ("C-c p a" . cape-abbrev)
         ("C-c p i" . cape-ispell)
         ("C-c p l" . cape-line)
         ("C-c p w" . cape-dict)
         ("C-c p \\" . cape-tex)
         ("C-c p &" . cape-sgml)
         ("C-c p r" . cape-rfc1345))
  :init
  ;; Add `completion-at-point-functions', used by `completion-at-point'.
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-tex)
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
)

; company-mode
(use-package company
  :ensure t
  :config
  ;; (global-company-mode 1)
  ;; (company-tng-mode)
  (setq company-tooltip-idle-delay 0.2)
  (setq company-idle-delay 0.1)
  ;;(setq company-backends '((company-capf company-files company-yasnippet company-dabbrev company-dabbrev-code)))
  ;; (setq company-backends '((company-capf company-files company-yasnippet)))
  (setq company-backends '(company-capf))
  (setq company-dabbrev-downcase nil)
  (setq company-transformers '(company-sort-by-occurrence delete-consecutive-dups))
  (setq company-minimum-prefix-length 1)
)
(use-package company-box)


;; You may prefer to use `initials' instead of `partial-completion'.
(use-package orderless
  :init
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (setq orderless-style-dispatchers '(+orderless-dispatch)
  ;;       orderless-component-separator #'orderless-escapable-split-on-space)

  ;; (setq orderless-component-separator "!") ;; will work for most PLs
  (setq completion-styles '(orderless)
        completion-category-defaults nil
        completion-category-overrides '((file (styles . (partial-completion))))))

;; Use dabbrev with Corfu!
(use-package dabbrev
  ;; Swap M-/ and C-M-/
  :bind (("M-/" . dabbrev-completion)
         ("C-M-/" . dabbrev-expand)))



;; ---- other completions

;; search
(use-package counsel
  :ensure t
  :config
  (counsel-mode 1)
  (setq ivy-initial-inputs-alist nil)
)

(use-package ivy
  :ensure t
  :diminish
  :bind (("C-s" . swiper)
	 :map ivy-minibuffer-map
	 ("TAB" . ivy-alt-done)
	 ("C-l" . ivy-alt-done)
	 ("C-j" . ivy-next-line)
	 ("C-k" . ivy-previous-line)
	 :map ivy-switch-buffer-map
	 ("C-k" . ivy-previous-line)
	 ("C-l" . ivy-done)
	 ("C-d" . ivy-switch-buffer-kill)
	 :map ivy-reverse-i-search-map
	 ("C-k" . ivy-previous-line)
	 ("C-d" . ivy-reverse-i-search-kill))
  :config
  (ivy-mode 1)
  (setq ivy-use-selectable-prompt t)
  (setq ivy-use-virtual-buffers t)
)

(use-package ivy-rich
  :ensure t
  :init
  (ivy-rich-mode 1))

(use-package ivy-xref
  :init
  (setq xref-show-xrefs-function #'ivy-xref-show-xrefs)
)

;;

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

(use-package company-posframe :config (company-posframe-mode 1))

;; ui
;; (use-package nord-theme :init (load-theme 'nord t))
(use-package doom-themes
  :ensure t
  :config
  ;; Global settings (defaults)
  (setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
        doom-themes-enable-italic t) ; if nil, italics is universally disabled
  ;; (load-theme 'doom-nord-light t)
  ;; (load-theme 'doom-nord t)
  ;; (load-theme 'doom-opera-light t)
  ;; (load-theme 'doom-flatwhite t)
  (load-theme 'doom-plain t)

  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (all-the-icons must be installed!)
  (doom-themes-neotree-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

(use-package olivetti :init (setq olivetti-body-width .67))
(use-package which-key
  :ensure t
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 1)
)

(use-package helpful
  :ensure t
  :custom
  (counsel-describe-function-function #'helpful-callable)
  (counsel-describe-variable-function #'helpful-variable)
  :bind
  ([remap describe-function] . counsel-describe-function)
  ([remap describe-command] . helpful-command)
  ([remap describe-variable] . counsel-describe-variable)
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
(use-package all-the-icons :if (display-graphic-p))


;; keybindings
(use-package general
    :ensure t
    :config
    (general-create-definer my/leader-keys
	:keymaps '(normal insert visual emacs)
	:prefix "SPC"
	:global-prefix "C-SPC")
)

(my/leader-keys "b" '(my/compile :which-key "compile"))
(my/leader-keys "r" '(my/run-app :which-key "run"))
;;(my/leader-keys "t" '(my/run-current-test :which-key "run current test"))
;; todo
(my/leader-keys "t" '(org-todo :which-key "change todo state"))

(my/leader-keys "Z" '(my/write-mode :which-key "zen mode"))
(my/leader-keys "z" '(my/write-mode-no-zoom :which-key "zen mode no zoom"))
(my/leader-keys "c" '(my/default-mode :which-key "code mode"))

(my/leader-keys "/" '(comment-or-uncomment-region :which-key "toggle comment"))

;; TODO fixme

(my/leader-keys "," '(counsel-switch-buffer :which-key "switch buffer"))
(my/leader-keys "<" '(counsel-switch-buffer :which-key "switch buffer"))
(my/leader-keys "f" '(counsel-find-file :which-key "find a file"))
;;(my/leader-keys "," '(helm-buffers-list :which-key "switch buffer"))
;;(my/leader-keys "<" '(helm-buffers-list :which-key "switch buffer"))
;;(my/leader-keys "g" '(helm-find-files :which-key "find a file"))
(my/leader-keys "e" '(org-set-effort :which-key "set effort for org-mode"))
(my/leader-keys "x" '(org-capture :which-key "capture task"))
(my/leader-keys "n" '(org-roam-node-find :which-key "roam files"))
(my/leader-keys "j" '(my/goto-journal :which-key "goto journal"))

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


(my/leader-keys "L" '(org-insert-link :which-key "insert link in org-mode"))
(my/leader-keys "l" '(display-line-numbers-mode :which-key "toggle line numbers"))

;; TODO: need this operation
(my/leader-keys "i" '(org-roam-node-insert :which-key "insert roam link"))
(my/leader-keys "I" '(counsel-org-link :which-key "insert heading link"))
(my/leader-keys "mt" '(org-roam-tag-add :which-key "add tag"))
(my/leader-keys "mT" '(org-roam-tag-remove :which-key "remove tag"))

(my/leader-keys "k" '(describe-key :which-key "describe key"))


(require 'tramp)
(setq tramp-message-show-message nil)
(add-to-list 'tramp-remote-path 'tramp-own-remote-path)

;;(setq ob-async-inject-variables "\\(\\borg-babel.+\\|tramp-.+\\)")
(setq ob-async-inject-variables "\\borg-babel.+")
(add-hook 'ob-async-pre-execute-src-block-hook
        '(lambda ()
           ;; tramp config for async emacs process
           (setq tramp-completion-reread-directory-timeout nil)
           (setq tramp-default-method "sshx")
           (setq tramp-use-ssh-controlmaster-options nil)
           (setq server-port "1492")
           (setq server-use-tcp t))
)


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
    (compile "cmake --build .")))

(defun my/run-app ()
  (interactive)
  (let ((default-directory (my/build-path)))
    (shell-command "./build/test.app/Contents/MacOS/test")))

;; https://yiming.dev/blog/2018/03/02/my-org-refile-workflow/
;; (defun org-search-heading ()
;;   (interactive)
;;   (org-refile '(4)))

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


(defvar my/default-font-size 130)
(defvar my/default-variable-font-size 130)

(set-face-attribute 'default nil :font "Menlo" :height my/default-font-size)
(set-face-attribute 'fixed-pitch nil :font "Menlo" :height my/default-font-size)
(set-face-attribute 'variable-pitch nil :font "Helvetica" :height my/default-variable-font-size :weight 'regular)

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
   (setq olivetti-body-width 80)
   (olivetti-mode 1)
   (text-scale-set 4.0)
   (display-line-numbers-mode 0)
   (company-mode 0)
)

(defun my/write-mode-no-zoom() (interactive)
   (setq olivetti-body-width 120)
   (olivetti-mode 1)
   (text-scale-set 0.0)
   (display-line-numbers-mode 0)
   (company-mode 0)
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
)

;; work / configurations
(defun my/connect-dev1 () (interactive)
  ;; TODO, actually connect
  (vterm "dev1")
)

(defun my/connect-dev2 () (interactive)
  (vterm "dev2")
)

(defun my/connect-dev-fair () (interactive)
  (vterm "devfair")
)

(defun my/connect-local () (interactive)
  (vterm "local")
)

;; TODO: graphql
;; - remove all keybindings excluding evil..?
;; - detect duplicate keybindings..?

;; TODO
;; (load "~/.config/emacs/graphql.el")

;;;(setq lc/mytasks-query "{\"query\": \"{'key':'AND','children':[{'key':'EQUALS_ANY_OF_TASK_STATUSES','field':'TASK_STATUS','value':['OPEN']},{'key':'EQUALS_ME','field':'TASK_OWNER_FBID','value':null}]}\"}")
;;;
;;;(setq gql-queries-folder "/Users/miguelmartin/repos/tasks")
;;;
;;;(defun my/tasks ()
;;;  (json-parse-string
;;;   (lc/gql
;;;    :sync t
;;;    :variables lc/mytasks-query
;;;    :query-file "all_tasks")))
;;;
;;;(defun format-task-node (n)
;;;  `(:id ,(number-to-string (ht-get n "task_number"))
;;;    :url ,(ht-get n "url")
;;;    :title ,(ht-get n "task_title")))
;;;
;;;(defun tasks-nodes ()
;;;  (let* ((raw (lc/mytasks))
;;;         (edges (ht-get* raw "task_search_query" "search_items" "edges")))
;;;    (cl-loop for n across edges collect (format-task-node (ht-get n "node")))))

;;(lc/gql :sync t :query-file "all_tasks_temp")
;;(lc/gql :sync t :query-string lc/mytasks-query)
;;(require graphql "~/.config/emacs/graphql.el")

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

(defun my/tab-key () (interactive)
  (indent-relative)
)
(global-set-key (kbd "TAB") 'my/tab-key)
(setq indent-tabs-mode nil)



(setq org-confirm-babel-evaluate nil)

;;(use-package ob-ipython :ensure t)
(require 'org-autolist "~/.config/emacs/backup/better-ret.el")
(add-hook 'org-mode-hook (lambda () (org-autolist-mode)))

(org-babel-do-load-languages 'org-babel-load-languages
    '(
        (shell . t)
        (python . t)
        ;;(ipython . t)
        (emacs-lisp . t)
        (C . t)
    )
)

(setq org-adapt-indentation nil)
