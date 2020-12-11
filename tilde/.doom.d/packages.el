;; -*- no-byte-compile: t; -*-
(package! mixed-pitch)
(package! org-fragtog)
(package! org-autolist)
(package! olivetti)
(package! org-roam-server)

(unpin! org-ref)
(unpin! ivy-bibtex)
(unpin! helm-bibtex)

;; https://github.com/org-roam/org-roam-bibtex
(package! org-roam-bibtex
  :recipe (:host github :repo "org-roam/org-roam-bibtex"))

;; When using org-roam via the `+roam` flag
(unpin! org-roam)

;; When using bibtex-completion via the `biblio` module
(unpin! bibtex-completion helm-bibtex ivy-bibtex)

(package! gscholar-bibtex)
