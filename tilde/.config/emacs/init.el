;; SECTION: fundamental  -*- lexical-binding: t; -*-
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
 '(org-agenda-files '("/Users/mig/org/journal.org"))
 '(package-selected-packages
   '(nim-mode org-autolist which-key vterm vi-tilde-fringe use-package
              undo-tree org-ref org-fragtog olivetti nord-theme
              lsp-ivy ivy-rich ivy-bibtex helpful gscholar-bibtex
              general flycheck evil-org evil-collection
              evil-better-visual-line dap-mode counsel company
              command-log-mode))
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
  ;; (load-env-vars "~/.zshrc")
  ;; (setenv "TERM" "xterm-256")
  (setenv "TERM" "")
)

(use-package websocket)
(use-package simple-httpd)
;;(use-package org-super-agenda)
;;(use-package org-ql)
;; (use-package org-ql
;;   :quelpa (org-ql :fetcher github :repo "alphapapa/org-ql"
;;             :files (:defaults (:exclude "helm-org-ql.el"))))


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



;; (package-install 'magit)
;; (package-install 'magit-section)
;; (package-install 'transient)
;; (package-install 'with-editor)
(setq server-kill-new-buffers t)

(use-package org
    :config
  (setq org-todo-keywords
	'((sequence "PROJ(P!)" "TODO(t!)" "POST(p!)" "DOING(d!)" "BLOCKED(b!)" "|" "DONE(f!)" "CANCELED(c!@)"))
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
	  ("t" "Add Task" entry (file+datetree "~/org/journal.org")
	   "* TODO %? \n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("l" "Log" entry (file+datetree "~/org/journal.org")
	   "* %T %? :log:" :empty-lines 1)
	  ("j" "Journal Entry" entry (file+datetree "~/org/journal.org")
	   "* %t :journal:\n%?" :empty-lines 1)

    ;; life
	  ("b" "Task: Backlog" entry (file+olp "~/org/life.org" "Backlog" "Inbox")
	   "* TODO %? :backlog:\n:LOGBOOK:\n- State \"TODO\" from  %U\n:END:" :empty-lines 1)
	  ("n" "Note" entry (file+olp+datetree "~/org/life.org" "Backlog" "Inbox")
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
  ; (add-hook 'org-mode-hook (lambda () (company-mode -1)))
  (with-eval-after-load 'corfu
    (add-hook 'org-mode-hook (lambda () (corfu-mode -1)))
  )

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

(use-package org-tempo)

(use-package org-fragtog
    :ensure t
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
  :straight (:repo "https://code.tecosaur.net/tec/inline-diff")
  :after gptel-rewrite) ;or use :defer


(use-package whisper
  :load-path "~/repos/whisper.el"
  :bind ("C-H-r" . whisper-run)
  :config
  (setq whisper-install-directory "~/repos/"
        whisper-model "large-v3-turbo"
        whisper-language "en"
        whisper-translate nil
        whisper-use-threads (/ (num-processors) 1)))

(defun rk/get-ffmpeg-device ()
  "Gets the list of devices available to ffmpeg.
The output of the ffmpeg command is pretty messy, e.g.
  [AVFoundation indev @ 0x7f867f004580] AVFoundation video devices:
  [AVFoundation indev @ 0x7f867f004580] [0] FaceTime HD Camera (Built-in)
  [AVFoundation indev @ 0x7f867f004580] AVFoundation audio devices:
  [AVFoundation indev @ 0x7f867f004580] [0] Cam Link 4K
  [AVFoundation indev @ 0x7f867f004580] [1] MacBook Pro Microphone
so we need to parse it to get the list of devices.
The return value contains two lists, one for video devices and one for audio devices.
Each list contains a list of cons cells, where the car is the device number and the cdr is the device name."
  (unless (string-equal system-type "darwin")
    (error "This function is currently only supported on macOS"))

  (let ((lines (string-split (shell-command-to-string "ffmpeg -list_devices true -f avfoundation -i dummy || true") "\n")))
    (cl-loop with at-video-devices = nil
             with at-audio-devices = nil
             with video-devices = nil
             with audio-devices = nil
             for line in lines
             when (string-match "AVFoundation video devices:" line)
             do (setq at-video-devices t
                      at-audio-devices nil)
             when (string-match "AVFoundation audio devices:" line)
             do (setq at-audio-devices t
                      at-video-devices nil)
             when (and at-video-devices
                       (string-match "\\[\\([0-9]+\\)\\] \\(.+\\)" line))
             do (push (cons (string-to-number (match-string 1 line)) (match-string 2 line)) video-devices)
             when (and at-audio-devices
                       (string-match "\\[\\([0-9]+\\)\\] \\(.+\\)" line))
             do (push (cons (string-to-number (match-string 1 line)) (match-string 2 line)) audio-devices)
             finally return (list (nreverse video-devices) (nreverse audio-devices)))))

(defun rk/find-device-matching (string type)
  "Get the devices from `rk/get-ffmpeg-device' and look for a device
matching `STRING'. `TYPE' can be :video or :audio."
  (let* ((devices (rk/get-ffmpeg-device))
         (device-list (if (eq type :video)
                          (car devices)
                        (cadr devices))))
    (cl-loop for device in device-list
             when (string-match-p string (cdr device))
             return (car device))))

(defcustom rk/default-audio-device nil
  "The default audio device to use for whisper.el and outher audio processes."
  :type 'string)

(defun rk/select-default-audio-device (&optional device-name)
  "Interactively select an audio device to use for whisper.el and other audio processes.
If `DEVICE-NAME' is provided, it will be used instead of prompting the user."
  (interactive)
  (let* ((audio-devices (cadr (rk/get-ffmpeg-device)))
         (indexes (mapcar #'car audio-devices))
         (names (mapcar #'cdr audio-devices))
         (name (or device-name (completing-read "Select audio device: " names nil t))))
    (setq rk/default-audio-device (rk/find-device-matching name :audio))
    (when (boundp 'whisper--ffmpeg-input-device)
      (setq whisper--ffmpeg-input-device (format ":%s" rk/default-audio-device)))))



(use-package org-roam :ensure t
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
   (define-key evil-normal-state-map (kbd "[-d") 'flymake-goto-next-error)
   (define-key evil-normal-state-map (kbd "]-d") 'flymake-goto-prev-error)
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
  :config
  (add-hook 'org-mode-hook 'evil-org-mode)
  (add-hook 'evil-org-mode-hook
	      (lambda ()
		(evil-org-set-key-theme)))
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys)
)

(use-package evil-better-visual-line
  :ensure t
  :config
  (evil-better-visual-line-on)
)

;; TODO removeme
;; (use-package vi-tilde-fringe
;;   :ensure t
;;   :config
;;   (global-vi-tilde-fringe-mode 1))

(use-package
  evil-numbers :ensure t
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

;; -- ----------
;; lsp
;; (use-package eglot
;;   :config
;;   (add-to-list 'eglot-server-programs
;;              `(swift-mode . ("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/sourcekit-lsp")))
;;   ;; (add-to-list 'eglot-server-programs
;;   ;;            `(nim-mode . ("~/")))
;; )
;; (use-package lsp-mode)

(use-package dap-mode)

;; languages
(use-package nim-mode)
(use-package zig-mode)
(use-package swift-mode)
;; https://justinramel.github.io/2013/09/25/vim-to-emacs-smart-tab/
;; (use-package smart-tab :config (global-smart-tab-mode t) (setq smart-tab-using-hippie-expand t))

(use-package markdown-mode
  :ensure t
  :mode ("README\\.md\\'" . gfm-mode)
  :init (setq markdown-command "multimarkdown"))


;; completion
(use-package corfu
  ;; Optional customizations
  :custom
  (corfu-auto-prefix 2)
  (corfu-auto t)
  (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  ;; (corfu-quit-at-boundary t)
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
  ; (global-corfu-mode)

  (keymap-unset corfu-map "RET")
  ;; (keymap-unset corfu-map "TAB")

  ;; Enable optional extension modes:
  (corfu-history-mode)
  (corfu-popupinfo-mode)
)
;; (use-package corfu-terminal :ensure t
;;   :unless (display-graphic-p)
;;   :after corfu
;;   :init (corfu-terminal-mode +1))


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
;; (use-package company
;;   :ensure t
;;   :config
;;   ;; (global-company-mode 1)
;;   ;; (company-tng-mode)
;;   (setq company-tooltip-idle-delay 0.2)
;;   (setq company-idle-delay 0.1)
;;   ;;(setq company-backends '((company-capf company-files company-yasnippet company-dabbrev company-dabbrev-code)))
;;   ;; (setq company-backends '((company-capf company-files company-yasnippet)))
;;   (setq company-backends '(company-capf))
;;   (setq company-dabbrev-downcase nil)
;;   (setq company-transformers '(company-sort-by-occurrence delete-consecutive-dups))
;;   (setq company-minimum-prefix-length 1)
;; )
;; (use-package company-box)
;; (use-package company-posframe :config (company-posframe-mode 1))


;; You may prefer to use `initials' instead of `partial-completion'.
(use-package orderless
  :init
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (setq orderless-style-dispatchers '(+orderless-dispatch)
  ;;       orderless-component-separator #'orderless-escapable-split-on-space)

  ;; (setq orderless-component-separator "!") ;; will work for most PLs
  (setq
    completion-styles '(orderless basic)
    completion-category-defaults nil
    completion-category-overrides '((file (styles . (partial-completion))))
  )
)

;; Use dabbrev with Corfu!
(use-package dabbrev
  ;; Swap M-/ and C-M-/
  :bind (("M-/" . dabbrev-completion)
         ("C-M-/" . dabbrev-expand)))



;; ---- other completions

;; search
(use-package consult :ensure t)
(use-package embark-consult :ensure t)
(use-package consult-eglot :ensure t :after consult)

; (use-package consult-omni
;   :straight (consult-omni :type git :host github :repo "armindarvish/consult-omni" :branch "main" :files (:defaults "sources/*.el"))
;   :after consult
;   :custom
;    ;; General settings that apply to all sources
;   (consult-omni-show-preview t) ;;; show previews
;   (consult-omni-preview-key "C-o") ;;; set the preview key to C-o
;   :config
;
;   ;; Load Sources Core code
;   (require 'consult-omni-sources)
;   ;; Load Embark Actions
;   (require 'consult-omni-embark)
;
;   (consult-omni-sources-load-modules)
;   ;; (setq consult-omni-default-interactive-command #'consult-omni-wikipedia)
;
;   (setq consult-omni-multi-sources '("calc"
;                                     ;; "File"
;                                     ;; "Buffer"
;                                     ;; "Bookmark"
;                                     "Apps"
;                                     ;; "gptel"
;                                     ;; "Brave"
;                                     "Dictionary"
;                                     "Google"
;                                     "Wikipedia"
;                                     "elfeed"
;                                     ;; "mu4e"
;                                     ;; "buffers text search"
;                                     "Notes Search"
;                                     "Org Agenda"
;                                     ;; "GitHub"
;                                     ;; "YouTube"
;                                     "Invidious"
;                                     )
;   )
; )

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

;; treesitter
(use-package tree-sitter
  :config
  (global-tree-sitter-mode)
)
(use-package tree-sitter-langs)
(use-package ts-fold
  :after tree-sitter
  :straight (ts-fold :type git :host github :repo "emacs-tree-sitter/ts-fold")
  :config (global-ts-fold-mode)
)


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
;; (use-package nord-theme :init (load-theme 'nord t))
(use-package doom-modeline
  :ensure t
  :hook (after-init . doom-modeline-mode)
  :config
  (setq doom-modeline-icon t)
  (setq doom-modeline-major-mode-color-icon t)
  (setq doom-modeline-minor-modes t)
)

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
  (load-theme 'doom-one-light t)

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

(define-key evil-normal-state-map (kbd "M-p") 'counsel-fzf)
(define-key evil-insert-state-map (kbd "M-p") 'counsel-fzf)
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

(my/leader-keys "," '(counsel-switch-buffer :which-key "switch buffer"))
(my/leader-keys "<" '(counsel-switch-buffer :which-key "switch buffer"))
(my/leader-keys "p" '(counsel-find-file :which-key "find a file"))
(my/leader-keys "e" '(org-set-effort :which-key "set effort for org-mode"))
(my/leader-keys "x" '(org-capture :which-key "capture task"))
(my/leader-keys "n" '(org-roam-node-find :which-key "roam files"))
(my/leader-keys "j" '(my/goto-journal :which-key "goto journal"))

(my/leader-keys "oc" '(org-table-recalculate-buffer-tables :which-key "recaclc tables in buffer"))
(my/leader-keys "on" '(org-id-get-create :which-key "create node"))
(my/leader-keys "ot" '(cousnel-org-tag :which-key "add tags"))

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
(my/leader-keys "I" '(counsel-org-link :which-key "insert heading link"))
(my/leader-keys "mt" '(org-roam-tag-add :which-key "add tag"))
(my/leader-keys "mT" '(org-roam-tag-remove :which-key "remove tag"))

(my/leader-keys "k" '(describe-key :which-key "describe key"))

; gptel bindings


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
           (setq tramp-use-ssh-controlmaster-options nil))
)

;; (setq server-use-tcp t)
;; (setq server-auth-dir (expand-file-name "~/.config/emacs/server"))


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

(defun my/tab-key () (interactive)
  (indent-relative)
)
(global-set-key (kbd "TAB") 'my/tab-key)
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
(setq-default python-indent-offset 4) ; Python
