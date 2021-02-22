;; -*- no-byte-compile: t; -*-
;;(package! mixed-pitch)
(package! org-fragtog)
;;(package! org-autolist)
(unpin! org-ref)

(package! olivetti)

;; https://github.com/org-roam/org-roam-bibtex
(package! org-roam-bibtex
  :recipe (:host github :repo "org-roam/org-roam-bibtex"))

;; When using bibtex-completion via the `biblio` module
(unpin! bibtex-completion helm-bibtex ivy-bibtex)
(package! gscholar-bibtex)

(package! evil-better-visual-line)


;; When using org-roam via the `+roam` flag
(unpin! org-roam)
(package! org-roam-server)

(package! command-log-mode)

;;(package! emacs-tree-sitter)

(package! fzf :recipe (:host github :repo "seenaburns/fzf.el" :branch "master"))
